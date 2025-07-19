defmodule Shared.Infrastructure.DeadLetterQueue do
  @moduledoc """
  デッドレターキュー（DLQ）の実装

  処理に失敗したメッセージを隔離し、手動での再処理や分析を可能にする。

  ## 機能
  - 失敗したメッセージの永続化
  - メッセージの手動再処理
  - 失敗理由の記録と分析
  - 期限切れメッセージの自動削除
  """

  use GenServer
  import Ecto.Query

  alias Shared.Infrastructure.DeadLetterQueue.DeadLetter
  alias Shared.Infrastructure.EventStore.Repo

  require Logger

  @default_retention_days 30
  @cleanup_interval_hours 24

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  失敗したメッセージをDLQに追加する

  ## Parameters
  - `source` - メッセージの送信元（例: "command_bus", "event_projection"）
  - `message` - 元のメッセージ
  - `error` - エラー情報
  - `metadata` - 追加のメタデータ（オプション）
  """
  @spec enqueue(String.t(), any(), any(), map()) :: {:ok, DeadLetter.t()} | {:error, term()}
  def enqueue(source, message, error, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:enqueue, source, message, error, metadata})
  end

  @doc """
  DLQからメッセージを取得する
  """
  @spec list_messages(Keyword.t()) :: {:ok, [DeadLetter.t()]} | {:error, term()}
  def list_messages(opts \\ []) do
    GenServer.call(__MODULE__, {:list_messages, opts})
  end

  @doc """
  特定のメッセージを再処理する
  """
  @spec reprocess(String.t(), function()) :: {:ok, any()} | {:error, term()}
  def reprocess(message_id, processor_fn) do
    GenServer.call(__MODULE__, {:reprocess, message_id, processor_fn})
  end

  @doc """
  メッセージを削除する
  """
  @spec delete(String.t()) :: :ok | {:error, term()}
  def delete(message_id) do
    GenServer.call(__MODULE__, {:delete, message_id})
  end

  @doc """
  統計情報を取得する
  """
  @spec get_stats() :: {:ok, map()}
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    retention_days = Keyword.get(opts, :retention_days, @default_retention_days)

    # 定期的なクリーンアップをスケジュール
    schedule_cleanup()

    state = %{
      retention_days: retention_days,
      stats: %{
        total_enqueued: 0,
        total_reprocessed: 0,
        total_deleted: 0
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:enqueue, source, message, error, metadata}, _from, state) do
    dead_letter = %{
      id: UUID.uuid4(),
      source: source,
      message: encode_message(message),
      error_message: format_error(error),
      error_details: encode_error_details(error),
      metadata:
        Map.merge(metadata, %{
          enqueued_at: DateTime.utc_now(),
          retry_count: Map.get(metadata, :retry_count, 0)
        }),
      status: "pending",
      created_at: DateTime.utc_now()
    }

    case Repo.insert(DeadLetter.changeset(%DeadLetter{}, dead_letter)) do
      {:ok, record} ->
        Logger.warning("Message added to DLQ: source=#{source}, id=#{record.id}")

        # Telemetry イベントを発行
        :telemetry.execute(
          [:dead_letter_queue, :enqueued],
          %{count: 1},
          %{source: source}
        )

        new_state = update_stats(state, :enqueued)
        {:reply, {:ok, record}, new_state}

      {:error, reason} = error ->
        Logger.error("Failed to enqueue message to DLQ: #{inspect(reason)}")
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:list_messages, opts}, _from, state) do
    source = Keyword.get(opts, :source)
    status = Keyword.get(opts, :status)
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)

    query = from(d in DeadLetter, order_by: [desc: d.created_at])

    query =
      query
      |> maybe_filter_by_source(source)
      |> maybe_filter_by_status(status)
      |> limit(^limit)
      |> offset(^offset)

    case Repo.all(query) do
      messages when is_list(messages) ->
        {:reply, {:ok, messages}, state}

      error ->
        {:reply, {:error, error}, state}
    end
  end

  @impl true
  def handle_call({:reprocess, message_id, processor_fn}, _from, state) do
    with {:ok, dead_letter} <- get_dead_letter(message_id),
         {:ok, message} <- decode_message(dead_letter.message) do
      # 再処理を実行
      result =
        try do
          processor_fn.(message)
        rescue
          e ->
            {:error, Exception.format(:error, e, __STACKTRACE__)}
        end

      # 結果に基づいてステータスを更新
      new_status =
        case result do
          {:ok, _} -> "reprocessed"
          _ -> "reprocess_failed"
        end

      update_result =
        dead_letter
        |> DeadLetter.changeset(%{
          status: new_status,
          reprocessed_at: DateTime.utc_now(),
          reprocess_result: encode_message(result)
        })
        |> Repo.update()

      case update_result do
        {:ok, _updated} ->
          Logger.info("Message reprocessed: id=#{message_id}, result=#{new_status}")

          :telemetry.execute(
            [:dead_letter_queue, :reprocessed],
            %{count: 1},
            %{status: new_status}
          )

          new_state = update_stats(state, :reprocessed)
          {:reply, result, new_state}

        {:error, reason} ->
          {:reply, {:error, {:update_failed, reason}}, state}
      end
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:delete, message_id}, _from, state) do
    case get_dead_letter(message_id) do
      {:ok, dead_letter} ->
        case Repo.delete(dead_letter) do
          {:ok, _} ->
            Logger.info("Message deleted from DLQ: id=#{message_id}")
            new_state = update_stats(state, :deleted)
            {:reply, :ok, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    db_stats =
      from(d in DeadLetter,
        select: %{
          total: count(d.id),
          by_status:
            fragment(
              "json_object_agg(status, count) FROM (SELECT status, COUNT(*) as count FROM dead_letters GROUP BY status) t"
            ),
          by_source:
            fragment(
              "json_object_agg(source, count) FROM (SELECT source, COUNT(*) as count FROM dead_letters GROUP BY source) t"
            )
        }
      )
      |> Repo.one()

    stats = Map.merge(state.stats, db_stats || %{})
    {:reply, {:ok, stats}, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_old_messages(state.retention_days)
    schedule_cleanup()
    {:noreply, state}
  end

  # Private functions

  defp get_dead_letter(message_id) do
    case Repo.get(DeadLetter, message_id) do
      nil -> {:error, :not_found}
      dead_letter -> {:ok, dead_letter}
    end
  end

  defp encode_message(message) do
    Jason.encode!(message)
  end

  defp decode_message(encoded) do
    case Jason.decode(encoded) do
      {:ok, message} -> {:ok, message}
      {:error, _} -> {:error, :decode_failed}
    end
  end

  defp format_error(error) when is_binary(error), do: error
  defp format_error(error) when is_atom(error), do: to_string(error)
  defp format_error({:error, reason}), do: format_error(reason)
  defp format_error(error), do: inspect(error)

  defp encode_error_details(error) do
    %{
      type: error_type(error),
      details: inspect(error),
      timestamp: DateTime.utc_now()
    }
  end

  defp error_type(error) when is_atom(error), do: "atom"
  defp error_type(error) when is_binary(error), do: "string"
  defp error_type({:error, _}), do: "error_tuple"
  defp error_type(%{__struct__: module}), do: "#{module}"
  defp error_type(_), do: "unknown"

  defp maybe_filter_by_source(query, nil), do: query

  defp maybe_filter_by_source(query, source) do
    from(d in query, where: d.source == ^source)
  end

  defp maybe_filter_by_status(query, nil), do: query

  defp maybe_filter_by_status(query, status) do
    from(d in query, where: d.status == ^status)
  end

  defp cleanup_old_messages(retention_days) do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-retention_days * 24 * 60 * 60, :second)

    {count, _} =
      from(d in DeadLetter,
        where: d.created_at < ^cutoff_date and d.status in ["reprocessed", "deleted"]
      )
      |> Repo.delete_all()

    if count > 0 do
      Logger.info("Cleaned up #{count} old messages from DLQ")
    end
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval_hours * 60 * 60 * 1000)
  end

  defp update_stats(state, :enqueued) do
    put_in(state, [:stats, :total_enqueued], state.stats.total_enqueued + 1)
  end

  defp update_stats(state, :reprocessed) do
    put_in(state, [:stats, :total_reprocessed], state.stats.total_reprocessed + 1)
  end

  defp update_stats(state, :deleted) do
    put_in(state, [:stats, :total_deleted], state.stats.total_deleted + 1)
  end
end

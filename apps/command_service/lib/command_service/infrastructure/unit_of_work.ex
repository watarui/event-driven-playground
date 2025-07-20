defmodule CommandService.Infrastructure.UnitOfWork do
  @moduledoc """
  Unit of Work パターンの実装

  トランザクション境界を管理し、複数のリポジトリ操作を
  単一のトランザクション内で実行します。
  """

  alias CommandService.Repo
  alias Shared.Infrastructure.EventStore.EventStore

  require Logger

  @doc """
  トランザクション内で処理を実行する

  ## Examples

      UnitOfWork.transaction(fn ->
        with {:ok, aggregate} <- CategoryRepository.get(id),
             {:ok, updated} <- CategoryAggregate.execute(aggregate, command),
             {:ok, _} <- CategoryRepository.save(updated) do
          {:ok, updated}
        end
      end)
  """
  def transaction(fun) when is_function(fun, 0) do
    Repo.transaction(fn ->
      case fun.() do
        {:ok, result} -> result
        {:error, reason} -> Repo.rollback(reason)
        result -> result
      end
    end)
  end

  @doc """
  アグリゲートとイベントを保存するトランザクション

  アグリゲートの状態保存とイベントストアへのイベント保存を
  同一トランザクション内で実行します。
  """
  def transaction_with_events(fun) when is_function(fun, 0) do
    Repo.transaction(fn ->
      # イベントを蓄積するプロセス辞書を初期化
      Process.put(:unit_of_work_events, [])

      case fun.() do
        {:ok, result} ->
          # 蓄積されたイベントを取得
          events = Process.get(:unit_of_work_events, []) |> Enum.reverse()
          Logger.debug("UnitOfWork: Retrieved #{length(events)} events from process dictionary")

          # イベントをイベントストアに保存
          case save_events(events) do
            :ok ->
              Logger.info("UnitOfWork: Successfully saved #{length(events)} events")
              # プロセス辞書をクリーンアップ
              Process.delete(:unit_of_work_events)
              result

            {:error, reason} ->
              Logger.error("UnitOfWork: Failed to save events - #{inspect(reason)}")
              Repo.rollback({:event_store_error, reason})
          end

        {:error, reason} ->
          Process.delete(:unit_of_work_events)
          Repo.rollback(reason)

        result ->
          Process.delete(:unit_of_work_events)
          result
      end
    end)
  end

  @doc """
  現在のトランザクションにイベントを追加する

  この関数は transaction_with_events 内でのみ使用してください。
  """
  def add_event(event) do
    current_events = Process.get(:unit_of_work_events, [])
    Process.put(:unit_of_work_events, [event | current_events])
    :ok
  end

  @doc """
  現在のトランザクションに複数のイベントを追加する
  """
  def add_events(events) when is_list(events) do
    Enum.each(events, &add_event/1)
    :ok
  end

  # Private functions

  defp save_events([]), do: :ok

  defp save_events(events) do
    Logger.debug("UnitOfWork.save_events called with #{length(events)} events")

    # グループ化してバッチ保存
    result =
      events
      |> Enum.group_by(fn event ->
        # aggregate_id または id フィールドを取得
        aggregate_id =
          case event do
            %{aggregate_id: id} -> id
            %{id: %{value: id}} -> id
            %{id: id} -> id
          end

        Logger.debug("Event for aggregate #{aggregate_id}: #{inspect(event.__struct__)}")
        aggregate_id
      end)
      |> Enum.reduce_while(:ok, fn {aggregate_id, aggregate_events}, :ok ->
        # アグリゲートタイプを最初のイベントから取得
        aggregate_type = get_aggregate_type(hd(aggregate_events))

        # 新規作成の場合は expected_version を -1 に設定（イベントがまだ存在しない）
        # TODO: 本来はアグリゲートのバージョンを使用すべきだが、現在は新規作成のみ対応
        expected_version = -1

        Logger.info(
          "Saving #{length(aggregate_events)} events for aggregate #{aggregate_id} (type: #{aggregate_type})"
        )

        case EventStore.append_events(
               aggregate_id,
               aggregate_type,
               aggregate_events,
               expected_version,
               %{}
             ) do
          {:ok, version} ->
            Logger.info(
              "Successfully saved events for aggregate #{aggregate_id}, new version: #{version}"
            )

            {:cont, :ok}

          {:error, reason} ->
            Logger.error(
              "Failed to save events for aggregate #{aggregate_id}: #{inspect(reason)}"
            )

            {:halt, {:error, reason}}
        end
      end)

    Logger.debug("UnitOfWork.save_events completed with result: #{inspect(result)}")
    result
  end

  defp get_aggregate_type(event) do
    cond do
      function_exported?(event.__struct__, :aggregate_type, 0) ->
        event.__struct__.aggregate_type()

      Map.has_key?(event, :aggregate_type) ->
        event.aggregate_type

      true ->
        # イベントモジュール名から推測
        event.__struct__
        |> Module.split()
        |> Enum.find(&String.contains?(&1, "Events"))
        |> case do
          "CategoryEvents" -> "category"
          "ProductEvents" -> "product"
          "OrderEvents" -> "order"
          _ -> "unknown"
        end
    end
  end
end

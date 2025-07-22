defmodule Shared.Infrastructure.DeadLetterQueue do
  @moduledoc """
  Dead Letter Queue の実装（Firestore版）

  処理に失敗したメッセージを保存し、後で再処理できるようにします。
  """

  alias Shared.Infrastructure.Firestore.Repository
  require Logger

  @collection "dead_letter_queue"

  @doc """
  メッセージをDead Letter Queueに追加する
  """
  def enqueue(message_type, message, error, metadata \\ %{}) do
    entry = %{
      id: UUID.uuid4(),
      message_type: to_string(message_type),
      message: message,
      error: format_error(error),
      metadata: metadata,
      retry_count: 0,
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    case Repository.save(@collection, entry.id, entry) do
      {:ok, _} ->
        Logger.warning("Message added to dead letter queue: #{message_type}")
        :ok

      error ->
        Logger.error("Failed to add message to dead letter queue: #{inspect(error)}")
        error
    end
  end

  @doc """
  Dead Letter Queue からメッセージを取得する
  """
  def dequeue(limit \\ 10) do
    opts = [
      limit: limit,
      order_by: {:created_at, :asc}
    ]

    case Repository.list(@collection, opts) do
      {:ok, entries} ->
        messages = Enum.map(entries, &parse_entry/1)
        {:ok, messages}

      error ->
        error
    end
  end

  @doc """
  特定のメッセージタイプのエントリを取得する
  """
  def get_by_type(message_type, limit \\ 100) do
    # TODO: Firestore のクエリ機能を使用して最適化
    case Repository.list(@collection, limit: limit) do
      {:ok, entries} ->
        filtered =
          entries
          |> Enum.map(&parse_entry/1)
          |> Enum.filter(fn entry ->
            entry.message_type == to_string(message_type)
          end)

        {:ok, filtered}

      error ->
        error
    end
  end

  @doc """
  メッセージを再処理のためにマークする
  """
  def mark_for_retry(entry_id) do
    with {:ok, data} <- Repository.get(@collection, entry_id) do
      updated =
        Map.merge(data, %{
          "retry_count" => (data["retry_count"] || 0) + 1,
          "updated_at" => DateTime.utc_now()
        })

      Repository.save(@collection, entry_id, updated)
    end
  end

  @doc """
  メッセージを削除する
  """
  def delete(entry_id) do
    Repository.delete(@collection, entry_id)
  end

  @doc """
  古いエントリをクリーンアップする
  """
  def cleanup_old_entries(days_to_keep \\ 30) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -days_to_keep * 24 * 60 * 60, :second)

    # TODO: バッチ削除の実装
    case Repository.list(@collection, []) do
      {:ok, entries} ->
        old_entries =
          Enum.filter(entries, fn entry ->
            case parse_datetime(entry["created_at"] || entry[:created_at]) do
              nil -> false
              created_at -> DateTime.compare(created_at, cutoff_date) == :lt
            end
          end)

        Enum.each(old_entries, fn entry ->
          delete(entry["id"] || entry[:id])
        end)

        {:ok, length(old_entries)}

      error ->
        error
    end
  end

  # Private functions

  defp format_error(error) when is_binary(error), do: error
  defp format_error(error) when is_atom(error), do: to_string(error)
  defp format_error(error), do: inspect(error)

  defp parse_entry(data) do
    %{
      id: data["id"] || data[:id],
      message_type: data["message_type"] || data[:message_type],
      message: data["message"] || data[:message],
      error: data["error"] || data[:error],
      metadata: data["metadata"] || data[:metadata] || %{},
      retry_count: data["retry_count"] || data[:retry_count] || 0,
      created_at: parse_datetime(data["created_at"] || data[:created_at]),
      updated_at: parse_datetime(data["updated_at"] || data[:updated_at])
    }
  end

  defp parse_datetime(nil), do: nil
  defp parse_datetime(%DateTime{} = dt), do: dt

  defp parse_datetime(string) when is_binary(string) do
    case DateTime.from_iso8601(string) do
      {:ok, datetime, _} -> datetime
      _ -> nil
    end
  end

  defp parse_datetime(_), do: nil
end

defmodule Shared.Health.Checks.EventStoreCheck do
  @moduledoc """
  イベントストアのヘルスチェック（Firestore ベース）
  """

  alias Shared.Infrastructure.Firestore.EventStoreAdapter
  require Logger

  @timeout 5_000

  @doc """
  イベントストアの接続状態を確認
  """
  def check do
    case perform_check() do
      :ok ->
        {:ok, %{status: :connected, operations: [:read, :write, :delete]}}

      {:error, reason} ->
        {:error, "EventStore check failed: #{inspect(reason)}", 
         %{
           error: inspect(reason),
           message: format_error_message(reason),
           original_type: inspect(reason)
         }}
    end
  end

  defp perform_check do
    # EventStoreAdapter の health_check を使用
    case EventStoreAdapter.health_check() do
      :ok -> :ok
      error -> error
    end
  rescue
    e ->
      {:error, {:exception, e}}
  end

  defp format_error_message({:write_failed, _}), do: "Failed to write to event store"
  defp format_error_message({:read_failed, _}), do: "Failed to read from event store"
  defp format_error_message({:exception, e}), do: "Exception: #{inspect(e)}"
  defp format_error_message(error), do: inspect(error)
end

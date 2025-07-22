defmodule Shared.Health.Checks.EventStoreCheck do
  @moduledoc """
  イベントストアのヘルスチェック（Firestore ベース）
  """

  alias Shared.Infrastructure.Firestore.EventStore
  require Logger

  @timeout 5_000

  @doc """
  イベントストアの接続状態を確認
  """
  def check do
    case perform_check() do
      :ok ->
        {:ok, %{status: :connected, operations: [:read, :write]}}

      {:error, reason} ->
        {:error, "EventStore check failed: #{inspect(reason)}", %{error: reason}}
    end
  end

  defp perform_check do
    with :ok <- check_write() do
      check_read()
    end
  end

  defp check_write do
    test_aggregate_id = "health_check_#{:erlang.unique_integer([:positive])}"

    test_event = %{
      aggregate_id: test_aggregate_id,
      event_type: "HealthCheckEvent",
      event_data: %{
        checked_at: DateTime.utc_now(),
        node: node()
      },
      metadata: %{
        correlation_id: UUID.uuid4(),
        causation_id: UUID.uuid4()
      }
    }

    case execute_with_timeout(fn ->
           # EventStore のインターフェースに合わせて調整
           EventStore.save_events(test_aggregate_id, [test_event], -1, %{})
         end) do
      {:ok, _} ->
        Process.put(:health_check_aggregate_id, test_aggregate_id)
        :ok

      error ->
        {:error, {:write_failed, error}}
    end
  end

  defp check_read do
    test_aggregate_id = Process.get(:health_check_aggregate_id)

    if test_aggregate_id do
      case execute_with_timeout(fn ->
             EventStore.get_events(test_aggregate_id, 0)
           end) do
        {:ok, events} when is_list(events) ->
          Process.delete(:health_check_aggregate_id)
          :ok

        error ->
          {:error, {:read_failed, error}}
      end
    else
      {:error, :no_test_aggregate}
    end
  end

  defp execute_with_timeout(fun) do
    task = Task.async(fun)

    case Task.yield(task, @timeout) || Task.shutdown(task) do
      {:ok, result} ->
        result

      nil ->
        {:error, :timeout}

      {:exit, reason} ->
        {:error, {:task_failed, reason}}
    end
  end
end

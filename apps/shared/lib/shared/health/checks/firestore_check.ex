defmodule Shared.Health.Checks.FirestoreCheck do
  @moduledoc """
  Firestore 接続のヘルスチェック
  """

  require Logger

  @collection "_health_check"
  @timeout 5_000

  @doc """
  Firestore の接続状態を確認
  """
  def check do
    case perform_check() do
      :ok ->
        {:ok, %{status: :connected, operations: [:read, :write, :delete]}}

      {:error, reason} ->
        {:error, "Firestore check failed: #{inspect(reason)}", %{error: reason}}
    end
  end

  defp perform_check do
    check_operations()
  end

  defp check_operations do
    with :ok <- check_write(),
         :ok <- check_read(),
         :ok <- check_delete() do
      :ok
    end
  end

  defp check_write do
    test_id = "health_check_#{:erlang.unique_integer([:positive])}"

    test_data = %{
      checked_at: DateTime.utc_now(),
      node: node(),
      service: System.get_env("CLOUD_RUN_SERVICE_NAME", "unknown")
    }

    case execute_with_timeout(fn ->
           Shared.Infrastructure.Firestore.Repository.save(@collection, test_id, test_data)
         end) do
      {:ok, _} ->
        Process.put(:health_check_doc_id, test_id)
        :ok

      error ->
        {:error, {:write_failed, error}}
    end
  end

  defp check_read do
    test_id = Process.get(:health_check_doc_id)

    if test_id do
      case execute_with_timeout(fn ->
             Shared.Infrastructure.Firestore.Repository.get(@collection, test_id)
           end) do
        {:ok, _data} ->
          :ok

        error ->
          {:error, {:read_failed, error}}
      end
    else
      {:error, :no_test_document}
    end
  end

  defp check_delete do
    test_id = Process.get(:health_check_doc_id)

    if test_id do
      case execute_with_timeout(fn ->
             Shared.Infrastructure.Firestore.Repository.delete(@collection, test_id)
           end) do
        :ok ->
          Process.delete(:health_check_doc_id)
          :ok

        error ->
          {:error, {:delete_failed, error}}
      end
    else
      :ok
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

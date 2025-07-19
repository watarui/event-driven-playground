defmodule ClientService.GraphQL.Resolvers.HealthResolver do
  @moduledoc """
  ヘルスチェック関連の GraphQL リゾルバー
  """

  alias Shared.Health.HealthChecker
  alias Shared.Health.Checks.MemoryCheck

  @doc """
  全体のヘルスチェックを実行
  """
  def get_health(_parent, _args, _resolution) do
    health_report = HealthChecker.check_health()
    {:ok, format_health_report(health_report)}
  end

  @doc """
  メモリ情報を取得
  """
  def get_memory_info(_parent, _args, _resolution) do
    case MemoryCheck.check() do
      {:ok, details} ->
        {:ok, details}

      {:degraded, _message, details} ->
        {:ok, details}

      {:error, _message, details} ->
        {:ok, details}
    end
  end

  @doc """
  特定のサービスのヘルスチェックを実行
  """
  def check_service(_parent, %{service_name: service_name}, _resolution) do
    service_atom = String.to_existing_atom(service_name)
    health_report = HealthChecker.check_health(service_atom)
    {:ok, format_health_report(health_report)}
  rescue
    ArgumentError ->
      {:error, "Unknown service: #{service_name}"}
  end

  # Private functions

  defp format_health_report(report) do
    %{
      status: report.status,
      timestamp: report.timestamp,
      checks: format_checks(report.checks),
      version: report.version,
      node: to_string(report.node)
    }
  end

  defp format_checks(checks) do
    Enum.map(checks, fn check ->
      %{
        name: check.name,
        status: check.status,
        message: check.message,
        details: check.details,
        duration_ms: check.duration_ms
      }
    end)
  end
end

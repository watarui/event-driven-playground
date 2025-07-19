defmodule Shared.Health.HealthChecker do
  @moduledoc """
  ヘルスチェックの実行と結果の集約

  各コンポーネントの健全性を確認し、システム全体の状態を判定します。
  """

  alias Shared.Health.Checks.{
    DatabaseCheck,
    EventStoreCheck,
    MemoryCheck,
    ServiceCheck,
    CircuitBreakerCheck
  }

  require Logger

  @type health_status :: :healthy | :degraded | :unhealthy
  @type check_result :: %{
          name: String.t(),
          status: health_status(),
          message: String.t(),
          details: map(),
          duration_ms: non_neg_integer()
        }
  @type health_report :: %{
          status: health_status(),
          timestamp: DateTime.t(),
          checks: [check_result()],
          version: String.t(),
          node: atom()
        }

  @doc """
  全てのヘルスチェックを実行
  """
  @spec check_health() :: health_report()
  def check_health do
    start_time = System.monotonic_time(:millisecond)

    checks = [
      run_check("database", &DatabaseCheck.check/0),
      run_check("event_store", &EventStoreCheck.check/0),
      run_check("memory", &MemoryCheck.check/0),
      run_check("services", &ServiceCheck.check/0),
      run_check("circuit_breakers", &CircuitBreakerCheck.check/0)
    ]

    overall_status = calculate_overall_status(checks)
    duration = System.monotonic_time(:millisecond) - start_time

    Logger.info(
      "Health check completed: status=#{overall_status}, duration=#{duration}ms, checks=#{length(checks)}"
    )

    %{
      status: overall_status,
      timestamp: DateTime.utc_now(),
      checks: checks,
      version: Application.spec(:shared, :vsn) |> to_string(),
      node: node()
    }
  end

  @doc """
  特定のチェックのみを実行
  """
  @spec check_health(atom() | [atom()]) :: health_report()
  def check_health(check_names) when is_list(check_names) do
    checks =
      check_names
      |> Enum.map(&check_health(&1))
      |> Enum.flat_map(& &1.checks)

    overall_status = calculate_overall_status(checks)

    %{
      status: overall_status,
      timestamp: DateTime.utc_now(),
      checks: checks,
      version: Application.spec(:shared, :vsn) |> to_string(),
      node: node()
    }
  end

  def check_health(check_name) when is_atom(check_name) do
    check =
      case check_name do
        :database -> run_check("database", &DatabaseCheck.check/0)
        :event_store -> run_check("event_store", &EventStoreCheck.check/0)
        :memory -> run_check("memory", &MemoryCheck.check/0)
        :services -> run_check("services", &ServiceCheck.check/0)
        :circuit_breakers -> run_check("circuit_breakers", &CircuitBreakerCheck.check/0)
        _ -> nil
      end

    checks = if check, do: [check], else: []
    overall_status = calculate_overall_status(checks)

    %{
      status: overall_status,
      timestamp: DateTime.utc_now(),
      checks: checks,
      version: Application.spec(:shared, :vsn) |> to_string(),
      node: node()
    }
  end

  @doc """
  簡易ヘルスチェック（liveness probe用）
  """
  @spec liveness_check() :: :ok | :error
  def liveness_check do
    # 基本的なプロセスの生存確認のみ
    if Process.alive?(Process.whereis(:event_bus)) do
      :ok
    else
      :error
    end
  end

  @doc """
  準備状態チェック（readiness probe用）
  """
  @spec readiness_check() :: :ok | :error
  def readiness_check do
    # データベース接続とイベントストアの確認
    with {:ok, _} <- DatabaseCheck.check(),
         {:ok, _} <- EventStoreCheck.check() do
      :ok
    else
      _ -> :error
    end
  end

  # Private functions

  defp run_check(name, check_fun) do
    start_time = System.monotonic_time(:millisecond)

    {status, message, details} =
      try do
        case check_fun.() do
          {:ok, details} ->
            {:healthy, "Check passed", details}

          {:degraded, message, details} ->
            {:degraded, message, details}

          {:error, message, details} ->
            {:unhealthy, message, details}

          {:error, message} ->
            {:unhealthy, message, %{}}
        end
      rescue
        e ->
          Logger.error("Health check failed for #{name}: #{inspect(e)}")
          {:unhealthy, "Check failed with exception", %{error: inspect(e)}}
      end

    duration = System.monotonic_time(:millisecond) - start_time

    %{
      name: name,
      status: status,
      message: message,
      details: details,
      duration_ms: duration
    }
  end

  defp calculate_overall_status(checks) do
    statuses = Enum.map(checks, & &1.status)

    cond do
      Enum.any?(statuses, &(&1 == :unhealthy)) -> :unhealthy
      Enum.any?(statuses, &(&1 == :degraded)) -> :degraded
      true -> :healthy
    end
  end
end

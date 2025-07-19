defmodule Shared.Health.HealthCheckRouter do
  @moduledoc """
  統一されたヘルスチェックエンドポイント
  
  /         - 基本的な生存確認
  /ready    - サービスの準備状態確認（DB接続等）
  /live     - 軽量な生存確認
  /detailed - 詳細なヘルスチェック情報
  """

  use Plug.Router
  alias Shared.Config

  plug :match
  plug :dispatch

  # 基本的なヘルスチェック
  get "/" do
    service_name = conn.private[:service_name] || "unknown"
    
    send_json(conn, 200, %{
      status: "ok",
      service: service_name,
      timestamp: DateTime.utc_now(),
      version: Application.spec(:shared, :vsn) |> to_string()
    })
  end

  # 軽量な生存確認（Kubernetes liveness probe 用）
  get "/live" do
    send_json(conn, 200, %{alive: true})
  end

  # 準備状態の確認（Kubernetes readiness probe 用）
  get "/ready" do
    health_config = Config.get_env_config(:health_check, %{})
    
    # データベース接続チェック
    db_checks = if Map.get(health_config, :check_database, true) do
      [check_database(conn.private[:repo])]
    else
      []
    end
    
    # 外部サービスチェック
    service_checks = if Map.get(health_config, :check_external_services, false) do
      check_external_services()
    else
      []
    end
    
    checks = db_checks ++ service_checks
    
    # すべてのチェックを実行
    results = Enum.map(checks, & &1.())
    all_healthy = Enum.all?(results, fn {_name, status, _details} -> status == :ok end)
    
    if all_healthy do
      send_json(conn, 200, %{
        ready: true,
        checks: format_check_results(results)
      })
    else
      send_json(conn, 503, %{
        ready: false,
        checks: format_check_results(results)
      })
    end
  end

  # 詳細なヘルスチェック情報
  get "/detailed" do
    service_name = conn.private[:service_name] || "unknown"
    health_config = Config.get_env_config(:health_check, %{})
    
    # 基本情報
    base_info = %{
      service: service_name,
      timestamp: DateTime.utc_now(),
      version: Application.spec(:shared, :vsn) |> to_string(),
      environment: Config.get_env_config(:environment, :unknown),
      uptime_seconds: get_uptime()
    }
    
    # システム情報
    system_info = %{
      erlang_version: :erlang.system_info(:version) |> to_string(),
      otp_release: :erlang.system_info(:otp_release) |> to_string(),
      schedulers: :erlang.system_info(:schedulers),
      process_count: :erlang.system_info(:process_count),
      memory: get_memory_info()
    }
    
    # 詳細チェックが有効な場合
    checks = if Map.get(health_config, :detailed_checks, false) do
      perform_detailed_checks(conn)
    else
      %{}
    end
    
    send_json(conn, 200, Map.merge(base_info, %{
      system: system_info,
      checks: checks
    }))
  end

  # プライベート関数

  defp send_json(conn, status, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(data))
  end

  defp check_database(nil), do: fn -> {"database", :error, "No repo configured"} end
  defp check_database(repo) do
    fn ->
      timeout = Config.get_env_config(:health_check, :check_timeout, 5_000)
      
      task = Task.async(fn ->
        try do
          case repo.query("SELECT 1", [], timeout: timeout) do
            {:ok, _} -> {"database", :ok, %{connected: true}}
            {:error, error} -> {"database", :error, inspect(error)}
          end
        rescue
          error -> {"database", :error, inspect(error)}
        end
      end)
      
      case Task.yield(task, timeout) || Task.shutdown(task) do
        {:ok, result} -> result
        _ -> {"database", :error, "Check timed out"}
      end
    end
  end

  defp check_external_services do
    [
      check_pubsub(),
      check_event_store()
    ]
  end

  defp check_pubsub do
    fn ->
      try do
        # PubSub の生存確認
        if Process.whereis(Phoenix.PubSub) do
          {"pubsub", :ok, %{status: "running"}}
        else
          {"pubsub", :error, "PubSub not running"}
        end
      rescue
        error -> {"pubsub", :error, inspect(error)}
      end
    end
  end

  defp check_event_store do
    fn ->
      try do
        # Event Store の接続確認
        repo = Module.concat([Shared.Infrastructure.EventStore.Repo])
        if Code.ensure_loaded?(repo) and function_exported?(repo, :query, 2) do
          case repo.query("SELECT COUNT(*) FROM event_store.events", []) do
            {:ok, %{rows: [[count]]}} -> 
              {"event_store", :ok, %{event_count: count}}
            {:error, error} -> 
              {"event_store", :error, inspect(error)}
          end
        else
          {"event_store", :error, "Event Store repo not available"}
        end
      rescue
        error -> {"event_store", :error, inspect(error)}
      end
    end
  end

  defp format_check_results(results) do
    Enum.map(results, fn {name, status, details} ->
      %{
        name: name,
        status: status,
        details: details
      }
    end)
  end

  defp get_uptime do
    {uptime, _} = :erlang.statistics(:wall_clock)
    div(uptime, 1000)
  end

  defp get_memory_info do
    memory = :erlang.memory()
    %{
      total_mb: div(memory[:total], 1_048_576),
      processes_mb: div(memory[:processes], 1_048_576),
      ets_mb: div(memory[:ets], 1_048_576),
      atom_mb: div(memory[:atom], 1_048_576),
      binary_mb: div(memory[:binary], 1_048_576)
    }
  end

  defp perform_detailed_checks(conn) do
    %{
      database: perform_database_check(conn.private[:repo]),
      services: perform_service_checks(),
      resources: perform_resource_checks()
    }
  end

  defp perform_database_check(nil), do: %{status: :error, message: "No repo configured"}
  defp perform_database_check(repo) do
    try do
      # 接続プールの状態
      pool_status = if function_exported?(repo, :pool_status, 0) do
        repo.pool_status()
      else
        %{}
      end
      
      # スキーマごとのテーブル数
      schemas = case repo.query("SELECT schema_name, COUNT(*) as table_count 
                                FROM information_schema.tables 
                                WHERE table_schema IN ('event_store', 'command', 'query')
                                GROUP BY schema_name", []) do
        {:ok, %{rows: rows}} ->
          Enum.map(rows, fn [schema, count] -> {schema, count} end) |> Enum.into(%{})
        _ ->
          %{}
      end
      
      %{
        status: :ok,
        pool: pool_status,
        schemas: schemas
      }
    rescue
      error -> %{status: :error, message: inspect(error)}
    end
  end

  defp perform_service_checks do
    %{
      pubsub: check_service(Phoenix.PubSub),
      telemetry: check_service(Telemetry.Registry)
    }
  end

  defp perform_resource_checks do
    %{
      cpu_usage: get_cpu_usage(),
      disk_usage: get_disk_usage(),
      open_ports: length(:erlang.ports()),
      atom_count: :erlang.system_info(:atom_count),
      atom_limit: :erlang.system_info(:atom_limit)
    }
  end

  defp check_service(module) do
    if Process.whereis(module) do
      %{status: :running}
    else
      %{status: :not_running}
    end
  end

  defp get_cpu_usage do
    # 簡易的な CPU 使用率の推定
    schedulers = :erlang.system_info(:schedulers_online)
    utilization = :scheduler.utilization(1) |> Enum.map(fn {_, util, _} -> util end)
    avg_utilization = Enum.sum(utilization) / length(utilization)
    
    %{
      schedulers: schedulers,
      average_utilization: Float.round(avg_utilization * 100, 2)
    }
  rescue
    _ -> %{error: "Unable to calculate CPU usage"}
  end

  defp get_disk_usage do
    # ディスク使用量の取得（Linux/macOS）
    case System.cmd("df", ["-h", "/"]) do
      {output, 0} ->
        lines = String.split(output, "\n")
        if length(lines) > 1 do
          [_header | [data | _]] = lines
          parts = String.split(data, ~r/\s+/)
          if length(parts) >= 5 do
            %{
              used: Enum.at(parts, 2),
              available: Enum.at(parts, 3),
              use_percent: Enum.at(parts, 4)
            }
          else
            %{error: "Unable to parse disk usage"}
          end
        else
          %{error: "Unable to get disk usage"}
        end
      _ ->
        %{error: "Unable to get disk usage"}
    end
  end
end
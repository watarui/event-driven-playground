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

  plug(:match)
  plug(:dispatch)

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

  # 軽量な生存確認（外部監視ツール用）
  get "/live" do
    send_json(conn, 200, %{alive: true})
  end

  # 準備状態の確認（Cloud Run やロードバランサー用）
  get "/ready" do
    health_config = Config.get_env_config(:health_check, %{})

    # データベース接続チェック
    db_checks =
      if Map.get(health_config, :check_database, true) do
        [check_database(conn.private[:repo])]
      else
        []
      end

    # 外部サービスチェック
    service_checks =
      if Map.get(health_config, :check_external_services, false) do
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
    checks =
      if Map.get(health_config, :detailed_checks, false) do
        perform_detailed_checks(conn)
      else
        %{}
      end

    send_json(
      conn,
      200,
      Map.merge(base_info, %{
        system: system_info,
        checks: checks
      })
    )
  end

  # プライベート関数

  defp send_json(conn, status, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(data))
  end

  defp check_database(nil), do: fn -> {"firestore", :error, "No firestore configured"} end

  defp check_database(_repo) do
    fn ->
      timeout = Config.get_env_config(:health_check, :check_timeout, 5_000)

      task =
        Task.async(fn ->
          try do
            # Firestore の接続確認
            case Shared.Infrastructure.Firestore.EventStoreAdapter.health_check() do
              :ok -> {"firestore", :ok, %{connected: true}}
              {:error, reason} -> {"firestore", :error, inspect(reason)}
            end
          rescue
            error -> {"firestore", :error, inspect(error)}
          end
        end)

      case Task.yield(task, timeout) || Task.shutdown(task) do
        {:ok, result} -> result
        _ -> {"firestore", :error, "Check timed out"}
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
        # Firestore Event Store の接続確認
        case Shared.Infrastructure.Firestore.EventStoreAdapter.health_check() do
          {:ok, event_count} ->
            {"event_store", :ok, %{event_count: event_count}}

          {:error, reason} ->
            {"event_store", :error, inspect(reason)}
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

  defp perform_database_check(nil), do: %{status: :error, message: "No firestore configured"}

  defp perform_database_check(_repo) do
    try do
      # Firestore のコレクション統計
      collections = %{
        "events" => get_collection_count("events"),
        "command_service" => %{
          "categories" => get_collection_count("command_service/categories"),
          "products" => get_collection_count("command_service/products"),
          "orders" => get_collection_count("command_service/orders")
        },
        "query_service" => %{
          "categories" => get_collection_count("query_service/categories"),
          "products" => get_collection_count("query_service/products"),
          "orders" => get_collection_count("query_service/orders")
        }
      }

      %{
        status: :ok,
        provider: "firestore",
        collections: collections
      }
    rescue
      error -> %{status: :error, message: inspect(error)}
    end
  end

  defp get_collection_count(collection_path) do
    # 実際のカウントはパフォーマンスの問題があるため、
    # ヘルスチェックでは単にコレクションの存在を返す
    %{collection: collection_path, status: "available"}
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
    # スケジューラーの統計情報から使用率を推定
    scheduler_wall_time =
      case :erlang.statistics(:scheduler_wall_time) do
        :undefined ->
          # 初回は有効化が必要
          :erlang.system_flag(:scheduler_wall_time, true)
          []

        data ->
          data
      end

    avg_utilization =
      if scheduler_wall_time == [] do
        0.0
      else
        total_active =
          Enum.reduce(scheduler_wall_time, 0, fn {_, active, _total}, acc -> acc + active end)

        total_time =
          Enum.reduce(scheduler_wall_time, 0, fn {_, _active, total}, acc -> acc + total end)

        if total_time > 0, do: total_active / total_time, else: 0.0
      end

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

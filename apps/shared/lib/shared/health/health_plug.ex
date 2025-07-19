defmodule Shared.Health.HealthPlug do
  @moduledoc """
  ヘルスチェックエンドポイント用の Plug

  /health、/health/live、/health/ready エンドポイントを提供します。
  """

  import Plug.Conn

  alias Shared.Health.HealthChecker

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%{path_info: ["health"]} = conn, _opts) do
    # 詳細なヘルスチェック
    health_report = HealthChecker.check_health()

    status_code =
      case health_report.status do
        :healthy -> 200
        # degraded でも 200 を返す（設定により変更可能）
        :degraded -> 200
        :unhealthy -> 503
      end

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status_code, Jason.encode!(health_report))
  end

  def call(%{path_info: ["health", "live"]} = conn, _opts) do
    # Liveness probe - 基本的な生存確認
    case HealthChecker.liveness_check() do
      :ok ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, "OK")

      :error ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(503, "Service Unavailable")
    end
  end

  def call(%{path_info: ["health", "ready"]} = conn, _opts) do
    # Readiness probe - サービス提供可能状態の確認
    case HealthChecker.readiness_check() do
      :ok ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, "Ready")

      :error ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(503, "Not Ready")
    end
  end

  def call(%{path_info: ["health", check_name]} = conn, _opts) when is_binary(check_name) do
    # 特定のチェックのみ実行
    check_atom = String.to_existing_atom(check_name)
    health_report = HealthChecker.check_health(check_atom)

    status_code =
      case health_report.status do
        :healthy -> 200
        :degraded -> 200
        :unhealthy -> 503
      end

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status_code, Jason.encode!(health_report))
  rescue
    ArgumentError ->
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(404, Jason.encode!(%{error: "Unknown health check: #{check_name}"}))
  end

  def call(conn, _opts) do
    conn
  end
end

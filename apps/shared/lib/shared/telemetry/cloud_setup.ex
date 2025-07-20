defmodule Shared.Telemetry.CloudSetup do
  @moduledoc """
  環境に応じた OpenTelemetry 設定
  開発環境では Jaeger、本番環境では Google Cloud Trace を使用
  """

  require Logger

  @doc """
  OpenTelemetry を環境に応じて設定する
  """
  def setup do
    if cloud_run_environment?() do
      setup_google_cloud()
    else
      setup_local_development()
    end
  end

  defp setup_google_cloud do
    Logger.info("Setting up OpenTelemetry for Google Cloud")

    # Google Cloud Trace への OTLP エクスポート設定
    :opentelemetry.set_text_map_propagator(:trace_context)

    # Google Cloud Trace OTLP エンドポイント
    # https://cloud.google.com/trace/docs/setup/otlp
    project_id = System.get_env("GOOGLE_CLOUD_PROJECT") || System.get_env("GCP_PROJECT")

    if project_id do
      Application.put_env(:opentelemetry_exporter, :otlp_protocol, :grpc)

      Application.put_env(
        :opentelemetry_exporter,
        :otlp_endpoint,
        "https://cloudtrace.googleapis.com:443"
      )

      Application.put_env(:opentelemetry_exporter, :otlp_headers, [
        {"x-goog-user-project", project_id}
      ])

      # 認証の設定（Cloud Run では自動的に処理される）
      if System.get_env("GOOGLE_APPLICATION_CREDENTIALS") do
        Application.put_env(:opentelemetry_exporter, :otlp_compression, :gzip)
      end
    else
      Logger.warning("GOOGLE_CLOUD_PROJECT not set, falling back to local tracing")
      setup_local_development()
    end

    # Cloud Run のメタデータを追加
    resource_attributes = [
      {"service.name", System.get_env("K_SERVICE", "event-driven-playground")},
      {"service.version", System.get_env("K_REVISION", "unknown")},
      {"cloud.provider", "gcp"},
      {"cloud.platform", "gcp_cloud_run"},
      {"cloud.region", extract_region()},
      {"cloud.account.id", project_id},
      {"faas.name", System.get_env("K_SERVICE", "unknown")},
      {"faas.version", System.get_env("K_REVISION", "unknown")}
    ]

    Application.put_env(:opentelemetry, :resource, resource_attributes)

    # トレースのサンプリング設定
    Application.put_env(:opentelemetry, :traces_exporter, :otlp)
    Application.put_env(:opentelemetry, :processor, :batch)
  end

  defp setup_local_development do
    Logger.info("Setting up OpenTelemetry for local development")

    # ローカル Jaeger への OTLP エクスポート
    Application.put_env(:opentelemetry_exporter, :otlp_protocol, :grpc)
    Application.put_env(:opentelemetry_exporter, :otlp_endpoint, "http://localhost:4317")

    resource_attributes = [
      {"service.name", "event-driven-playground-local"},
      {"service.version", "dev"},
      {"environment", "development"}
    ]

    Application.put_env(:opentelemetry, :resource, resource_attributes)
  end

  defp cloud_run_environment? do
    System.get_env("K_SERVICE") != nil
  end

  defp extract_region do
    # K_CONFIGURATION からリージョンを抽出
    # 例: "my-service-abcde-us-central1" -> "us-central1"
    case System.get_env("K_CONFIGURATION") do
      nil ->
        "unknown"

      config ->
        parts = String.split(config, "-")

        if length(parts) >= 3 do
          parts
          |> Enum.slice(-2..-1)
          |> Enum.join("-")
        else
          "unknown"
        end
    end
  end
end

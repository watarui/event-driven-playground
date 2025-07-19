import Config

# 共通設定
config :shared,
  ecto_repos: [Shared.Infrastructure.EventStore.Repo],
  generators: [timestamp_type: :utc_datetime]

config :command_service,
  ecto_repos: [CommandService.Repo],
  generators: [timestamp_type: :utc_datetime]

config :query_service,
  ecto_repos: [QueryService.Repo],
  generators: [timestamp_type: :utc_datetime]

# Phoenix 設定
config :phoenix, :json_library, Jason
config :phoenix, :format_encoders, json: Jason

# Client Service Phoenix エンドポイント
config :client_service, ClientServiceWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [json: ClientServiceWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: ClientService.PubSub

# Absinthe GraphQL 設定
config :absinthe, :json_codec, Jason

# Logger 設定
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Elixir の JSON ライブラリ
config :elixir, :json_library, Jason

# OpenTelemetry 基本設定
config :opentelemetry,
  resource: [
    service: [
      name: "event-driven-playground",
      namespace: "event-driven-playground"
    ]
  ],
  span_processor: :batch,
  traces_exporter: :otlp

# 開発環境用のデフォルト設定
config :opentelemetry_exporter,
  otlp_protocol: :grpc,
  otlp_endpoint: "http://localhost:4317"

# Firebase プロジェクト ID（環境変数から取得可能）
config :client_service, :firebase_project_id, System.get_env("FIREBASE_PROJECT_ID")

# 環境固有の設定をインポート
import_config "#{config_env()}.exs"
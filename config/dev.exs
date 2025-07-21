import Config

# 開発環境の共通設定
config :shared,
  environment: :dev,
  # Firestore を使用する場合は :firestore に変更
  database_adapter: :firestore,
  database: %{
    pool_size: 10,
    show_sensitive_data_on_connection_error: true,
    ssl: false
  }

# Firestore Emulator の設定（開発環境）
if Application.get_env(:shared, :database_adapter) == :firestore do
  System.put_env("FIRESTORE_EMULATOR_HOST_EVENT_STORE", "localhost:8080")
  System.put_env("FIRESTORE_EMULATOR_HOST_COMMAND", "localhost:8081")
  System.put_env("FIRESTORE_EMULATOR_HOST_QUERY", "localhost:8082")
  System.put_env("FIRESTORE_PROJECT_ID_EVENT_STORE", "event-store-local")
  System.put_env("FIRESTORE_PROJECT_ID_COMMAND", "command-service-local")
  System.put_env("FIRESTORE_PROJECT_ID_QUERY", "query-service-local")
  # Query Service のポート設定
  System.put_env("PORT", "4082")
else
  # PostgreSQL の設定（従来の設定）
  config :shared, Shared.Infrastructure.EventStore.Repo,
    username: "postgres",
    password: "postgres",
    hostname: "localhost",
    database: "event_driven_playground_event_dev",
    port: 5432,
    pool_size: 10,
    show_sensitive_data_on_connection_error: true

  config :command_service, CommandService.Repo,
    username: "postgres",
    password: "postgres",
    hostname: "localhost",
    database: "event_driven_playground_command_dev",
    port: 5433,
    pool_size: 10,
    show_sensitive_data_on_connection_error: true

  config :query_service, QueryService.Repo,
    username: "postgres",
    password: "postgres",
    hostname: "localhost",
    database: "event_driven_playground_query_dev",
    port: 5434,
    pool_size: 10,
    show_sensitive_data_on_connection_error: true
end

# Phoenix エンドポイント設定
config :client_service, ClientServiceWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "bxXCJJi2L0Y1zhY5Y8kNMJyKeAOvTcLIA0lS0T+wC9wD6QvQW4fXKNj3+lWH0t9E",
  watchers: []

# 開発環境のルートを有効化
config :client_service, dev_routes: true

# Query Service エンドポイント設定
config :query_service, QueryServiceWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4082],
  server: false

# Command Service エンドポイント設定  
config :command_service, CommandServiceWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4081],
  server: false

# ログレベル
config :logger, :console, format: "[$level] $message\n"

# HEEx テンプレートのデバッグ
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

# 開発環境では認証を無効化
config :client_service, :auth_mode, :disabled
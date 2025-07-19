import Config

# 開発環境のデータベース設定
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

# ログレベル
config :logger, :console, format: "[$level] $message\n"

# HEEx テンプレートのデバッグ
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

# 開発環境では認証を無効化
config :client_service, :auth_mode, :disabled
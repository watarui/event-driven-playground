import Config

# 開発環境の共通設定
config :shared,
  environment: :dev,
  # Firestore を使用する場合は :firestore に変更
  database_adapter: :firestore

# Firestore Emulator の設定（開発環境）
# 単一の Firestore エミュレータを使用
System.put_env("FIRESTORE_EMULATOR_HOST", "localhost:8090")
System.put_env("FIRESTORE_PROJECT_ID", "demo-project")

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
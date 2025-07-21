import Config

# テスト環境の設定

# Print only warnings and errors during test
config :logger, level: :warning

# Phoenix エンドポイントのテスト設定
config :client_service, ClientServiceWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test-secret-key-base-at-least-64-bytes-long-for-testing-purposes-only",
  server: false

# Guardian のテスト設定
config :client_service, ClientService.Auth.Guardian,
  issuer: "client_service",
  secret_key: "test-secret-key-for-guardian"

# テスト環境では Firebase を使用しない
config :client_service, :use_firebase, false

# テスト環境では認証を無効化（任意）
config :client_service, :auth_mode, :test

# テスト環境では CircuitBreaker を起動しない
config :shared, :start_circuit_breaker, false

# テスト環境では同期的な EventBus を使用
config :shared, :event_bus_module, Shared.Infrastructure.EventBus.LocalEventBus

# Firebase のテスト用プロジェクト ID
config :client_service, :firebase_project_id, "test-project"

# QueryService の Phoenix エンドポイントを無効化
config :query_service, QueryServiceWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4003],
  secret_key_base: "test-secret-key-base-at-least-64-bytes-long-for-testing-purposes-only",
  server: false

# データベース設定（テスト用）
config :shared, Shared.Infrastructure.EventStore.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "event_driven_playground_event_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :command_service, CommandService.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "event_driven_playground_command_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :query_service, QueryService.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "event_driven_playground_query_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# CI 環境でのホスト設定
if System.get_env("GITHUB_ACTIONS") do
  config :shared, Shared.Infrastructure.EventStore.Repo,
    hostname: System.get_env("POSTGRES_HOST", "localhost")
    
  config :command_service, CommandService.Repo,
    hostname: System.get_env("POSTGRES_HOST", "localhost")
    
  config :query_service, QueryService.Repo,
    hostname: System.get_env("POSTGRES_HOST", "localhost")
end

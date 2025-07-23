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

# Firestore エミュレータを使用
config :shared, :firestore_emulator_host, "localhost:8090"

# テスト環境では認証不要
config :goth, disabled: true

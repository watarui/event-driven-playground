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

# テスト環境では認証を無効化（任意）
config :client_service, :auth_mode, :disabled

# QueryService の Phoenix エンドポイントを無効化
config :query_service, QueryServiceWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4003],
  secret_key_base: "test-secret-key-base-at-least-64-bytes-long-for-testing-purposes-only",
  server: false

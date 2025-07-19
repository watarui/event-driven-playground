import Config

# 本番環境の設定

# Logger を JSON フォーマットで出力（Axiom 用）
config :logger, :console,
  format: {Jason, :encode!},
  metadata: [:request_id, :trace_id, :span_id, :aggregate_id, :event_type, :service]

config :logger, level: :info

# 本番環境では Firebase 認証を使用
config :client_service, :auth_mode, :firebase

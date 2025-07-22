import Config

# 本番環境の設定
config :shared,
  environment: :prod,
  # 本番環境では Firestore を使用
  database_adapter: :firestore

# Logger を JSON フォーマットで出力（Axiom 用）
config :logger, :console,
  format: {Jason, :encode!},
  metadata: [:request_id, :trace_id, :span_id, :aggregate_id, :event_type, :service]

config :logger, level: :info

# 本番環境では Firebase 認証を使用
config :client_service, :auth_mode, :firebase

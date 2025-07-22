import Config
alias Shared.Config


# 本番環境でのみ実行時設定を適用
if config_env() == :prod do
  # Secret Key Base
  config :shared, :secret_key_base,
    System.get_env("SECRET_KEY_BASE") ||
      raise("environment variable SECRET_KEY_BASE is missing.")


  # Phoenix エンドポイント設定（Shared.Config を使用）
  config :client_service, ClientServiceWeb.Endpoint,
    Shared.Config.endpoint_config(port: String.to_integer(System.get_env("PORT") || "8080"))

  # Command Service エンドポイント設定
  config :command_service, CommandServiceWeb.Endpoint,
    Shared.Config.endpoint_config(port: String.to_integer(System.get_env("PORT") || "8080"))

  # Query Service エンドポイント設定
  config :query_service, QueryServiceWeb.Endpoint,
    Shared.Config.endpoint_config(port: String.to_integer(System.get_env("PORT") || "8080"))

  # Firebase 設定
  if System.get_env("FIREBASE_PROJECT_ID") do
    config :client_service, :firebase_project_id, System.get_env("FIREBASE_PROJECT_ID")
    config :client_service, :firebase_api_key, System.get_env("FIREBASE_API_KEY")
  end

  # Google Cloud Run 環境の自動検出
  if System.get_env("K_SERVICE") do
    config :shared, :environment, :cloud_run
    config :shared, :service_name, System.get_env("K_SERVICE")
    config :shared, :service_revision, System.get_env("K_REVISION")
  end
end
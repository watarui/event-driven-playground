import Config
alias Shared.Config

# テスト環境のデータベース設定
if config_env() == :test do
  # テスト環境用のデフォルト DATABASE_URL を設定
  System.put_env("DATABASE_URL", 
    System.get_env("DATABASE_URL") || "postgresql://postgres:postgres@localhost/event_driven_playground_test"
  )
  
  # データベース設定（Shared.Config を使用）
  config :shared, Shared.Infrastructure.EventStore.Repo,
    Shared.Config.database_config(:event_store)
    |> Keyword.merge(pool: Ecto.Adapters.SQL.Sandbox)
    
  config :command_service, CommandService.Repo,
    Shared.Config.database_config(:command_service)
    |> Keyword.merge(pool: Ecto.Adapters.SQL.Sandbox)
    
  config :query_service, QueryService.Repo,
    Shared.Config.database_config(:query_service)
    |> Keyword.merge(pool: Ecto.Adapters.SQL.Sandbox)
end

# 本番環境でのみ実行時設定を適用
if config_env() == :prod do
  # Secret Key Base
  config :shared, :secret_key_base,
    System.get_env("SECRET_KEY_BASE") ||
      raise("environment variable SECRET_KEY_BASE is missing.")

  # データベース設定（Shared.Config を使用）
  config :shared, Shared.Infrastructure.EventStore.Repo,
    Shared.Config.database_config(:event_store)
    
  config :command_service, CommandService.Repo,
    Shared.Config.database_config(:command_service)
    |> Keyword.merge(
      schema_search_path: "command,public",
      migration_default_prefix: "command"
    )
    
  config :query_service, QueryService.Repo,
    Shared.Config.database_config(:query_service)
    |> Keyword.merge(
      schema_search_path: "query,public",
      migration_default_prefix: "query"
    )

  # Phoenix エンドポイント設定（Shared.Config を使用）
  config :client_service, ClientServiceWeb.Endpoint,
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
defmodule CreateSchemas do
  use Ecto.Migration

  def up do
    # 本番環境でのみスキーマを作成
    if System.get_env("MIX_ENV") == "prod" && System.get_env("DATABASE_URL") do
      # Event Store スキーマ
      execute("CREATE SCHEMA IF NOT EXISTS event_store")
      
      # Command スキーマ
      execute("CREATE SCHEMA IF NOT EXISTS command")
      
      # Query スキーマ
      execute("CREATE SCHEMA IF NOT EXISTS query")
      
      # 権限を付与
      execute("GRANT ALL ON SCHEMA event_store TO postgres")
      execute("GRANT ALL ON SCHEMA command TO postgres")
      execute("GRANT ALL ON SCHEMA query TO postgres")
    end
  end

  def down do
    if System.get_env("MIX_ENV") == "prod" && System.get_env("DATABASE_URL") do
      execute("DROP SCHEMA IF EXISTS event_store CASCADE")
      execute("DROP SCHEMA IF EXISTS command CASCADE")
      execute("DROP SCHEMA IF EXISTS query CASCADE")
    end
  end
end
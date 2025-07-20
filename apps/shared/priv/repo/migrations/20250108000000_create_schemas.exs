defmodule Shared.Infrastructure.EventStore.Repo.Migrations.CreateSchemas do
  use Ecto.Migration

  def up do
    # テスト環境と本番環境でのみスキーマを作成
    # 開発環境では別々のデータベースを使用するため不要
    if Mix.env() in [:test, :prod] do
      # event_store スキーマを作成
      execute "CREATE SCHEMA IF NOT EXISTS event_store"
      
      # command_service スキーマを作成
      execute "CREATE SCHEMA IF NOT EXISTS command_service"
      
      # query_service スキーマを作成
      execute "CREATE SCHEMA IF NOT EXISTS query_service"
    end
  end

  def down do
    if Mix.env() in [:test, :prod] do
      # 注意: CASCADE を使用するとスキーマ内のすべてのオブジェクトが削除される
      execute "DROP SCHEMA IF EXISTS query_service CASCADE"
      execute "DROP SCHEMA IF EXISTS command_service CASCADE"
      execute "DROP SCHEMA IF EXISTS event_store CASCADE"
    end
  end
end
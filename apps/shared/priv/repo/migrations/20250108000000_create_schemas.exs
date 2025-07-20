defmodule Shared.Infrastructure.EventStore.Repo.Migrations.CreateSchemas do
  use Ecto.Migration

  def up do
    # スキーマを作成（IF NOT EXISTS により冪等性を保証）
    execute "CREATE SCHEMA IF NOT EXISTS event_store"
    execute "CREATE SCHEMA IF NOT EXISTS command_service"
    execute "CREATE SCHEMA IF NOT EXISTS query_service"
  end

  def down do
    # 注意: CASCADE を使用するとスキーマ内のすべてのオブジェクトが削除される
    execute "DROP SCHEMA IF EXISTS query_service CASCADE"
    execute "DROP SCHEMA IF EXISTS command_service CASCADE"
    execute "DROP SCHEMA IF EXISTS event_store CASCADE"
  end
end
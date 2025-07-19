defmodule Shared.Repo.Migrations.AddEventSchemaVersion do
  use Ecto.Migration

  def change do
    alter table(:events, prefix: "event_store") do
      add :schema_version, :integer, default: 1, null: false
    end
    
    # スキーマバージョンでフィルタリングするためのインデックス
    create index(:events, [:event_type, :schema_version], prefix: "event_store")
  end
end
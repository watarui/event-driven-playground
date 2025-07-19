defmodule Shared.Infrastructure.EventStore.Repo.Migrations.CreateEventStore do
  use Ecto.Migration

  def change do
    create table(:events, prefix: "event_store") do
      add :aggregate_id, :uuid, null: false
      add :aggregate_type, :string, null: false
      add :event_type, :string, null: false
      add :event_data, :map, null: false
      add :event_version, :integer, null: false
      add :metadata, :map, default: %{}

      timestamps()
    end

    # アグリゲートIDとバージョンの複合ユニークインデックス
    create unique_index(:events, [:aggregate_id, :event_version], prefix: "event_store")

    # パフォーマンス向上のためのインデックス
    create index(:events, [:aggregate_id], prefix: "event_store")
    create index(:events, [:event_type], prefix: "event_store")
    create index(:events, [:inserted_at], prefix: "event_store")
  end
end

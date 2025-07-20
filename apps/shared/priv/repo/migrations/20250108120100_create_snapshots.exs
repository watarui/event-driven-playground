defmodule Shared.Repo.Migrations.CreateSnapshots do
  use Ecto.Migration

  def change do
    create table(:snapshots, primary_key: false, prefix: "event_store") do
      add :id, :uuid, primary_key: true
      add :aggregate_id, :string, null: false
      add :aggregate_type, :string, null: false
      add :version, :integer, null: false
      add :data, :map, null: false
      add :metadata, :map, default: %{}
      
      timestamps(type: :utc_datetime_usec)
    end

    # 各アグリゲートの最新スナップショットを効率的に取得するためのインデックス
    create index(:snapshots, [:aggregate_id, :version], 
      name: :snapshots_aggregate_id_version_index,
      unique: true,
      prefix: "event_store")
    
    # アグリゲートタイプでフィルタリングするためのインデックス
    create index(:snapshots, [:aggregate_type], prefix: "event_store")
    
    # 作成日時でソートするためのインデックス
    create index(:snapshots, [:inserted_at], prefix: "event_store")
  end
end
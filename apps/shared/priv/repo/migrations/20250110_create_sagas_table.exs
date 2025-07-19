defmodule Shared.Infrastructure.EventStore.Repo.Migrations.CreateSagasTable do
  use Ecto.Migration

  def change do
    create table(:sagas, primary_key: false, prefix: "event_store") do
      add :id, :uuid, primary_key: true
      add :saga_type, :string, null: false
      add :state, :jsonb, null: false
      add :current_step, :string
      add :status, :string, null: false
      add :created_at, :utc_datetime_usec, null: false
      add :updated_at, :utc_datetime_usec, null: false
    end

    create index(:sagas, [:status], prefix: "event_store")
    create index(:sagas, [:saga_type], prefix: "event_store")
    create index(:sagas, [:created_at], prefix: "event_store")
  end
end
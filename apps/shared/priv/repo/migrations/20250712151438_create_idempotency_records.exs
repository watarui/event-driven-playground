defmodule Shared.Infrastructure.Repo.Migrations.CreateIdempotencyRecords do
  use Ecto.Migration

  def change do
    create table(:idempotency_records, primary_key: false, prefix: "event_store") do
      add :id, :binary_id, primary_key: true
      add :key, :string, null: false
      add :result, :map, null: false
      add :expires_at, :utc_datetime, null: false
      add :created_at, :utc_datetime, null: false
      add :updated_at, :utc_datetime, null: false
    end

    create unique_index(:idempotency_records, [:key], prefix: "event_store")
    create index(:idempotency_records, [:expires_at], prefix: "event_store")
  end
end

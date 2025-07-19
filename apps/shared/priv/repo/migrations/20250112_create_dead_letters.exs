defmodule Shared.Infrastructure.EventStore.Repo.Migrations.CreateDeadLetters do
  use Ecto.Migration

  def change do
    create table(:dead_letters, primary_key: false, prefix: "event_store") do
      add :id, :uuid, primary_key: true
      add :source, :string, null: false
      add :message, :text, null: false
      add :error_message, :text, null: false
      add :error_details, :map
      add :metadata, :map
      add :status, :string, null: false, default: "pending"
      add :reprocessed_at, :utc_datetime
      add :reprocess_result, :text

      timestamps()
    end

    create index(:dead_letters, [:source], prefix: "event_store")
    create index(:dead_letters, [:status], prefix: "event_store")
    create index(:dead_letters, [:inserted_at], prefix: "event_store")
  end
end
defmodule QueryService.Repo.Migrations.AddSagaFieldsToOrders do
  use Ecto.Migration

  def change do
    alter table(:orders, prefix: "query") do
      add :saga_id, :string
      add :saga_status, :string
      add :saga_current_step, :string
    end

    create index(:orders, [:saga_id], prefix: "query")
    create index(:orders, [:saga_status], prefix: "query")
  end
end
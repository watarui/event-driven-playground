defmodule QueryService.Repo.Migrations.CreateCategories do
  use Ecto.Migration

  def change do
    create table(:categories, primary_key: false, prefix: "query") do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :parent_id, :uuid
      add :active, :boolean, default: true, null: false
      add :product_count, :integer, default: 0, null: false
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:categories, [:parent_id], prefix: "query")
    create index(:categories, [:active], prefix: "query")
    create index(:categories, [:name], prefix: "query")
  end
end
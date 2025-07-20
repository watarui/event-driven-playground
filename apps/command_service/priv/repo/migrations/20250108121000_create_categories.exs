defmodule CommandService.Repo.Migrations.CreateCategories do
  use Ecto.Migration

  def change do
    create table(:categories, primary_key: false, prefix: "command") do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :parent_id, :uuid
      add :active, :boolean, default: true, null: false
      add :version, :integer, default: 0, null: false
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:categories, [:parent_id], prefix: "command")
    create index(:categories, [:active], prefix: "command")
    create unique_index(:categories, [:name], prefix: "command")
  end
end
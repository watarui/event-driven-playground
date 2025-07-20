defmodule QueryService.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    create table(:products, primary_key: false, prefix: "query") do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :category_id, :uuid, null: false
      add :category_name, :string, null: false
      add :price_amount, :decimal, precision: 10, scale: 2, null: false
      add :price_currency, :string, default: "JPY", null: false
      add :stock_quantity, :integer, default: 0, null: false
      add :active, :boolean, default: true, null: false
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:products, [:category_id], prefix: "query")
    create index(:products, [:active], prefix: "query")
    create index(:products, [:name], prefix: "query")
    create index(:products, [:price_amount], prefix: "query")
  end
end
defmodule QueryService.Repo.Migrations.CreateOrders do
  use Ecto.Migration

  def change do
    create table(:orders, primary_key: false, prefix: "query") do
      add :id, :string, primary_key: true
      add :user_id, :string, null: false
      add :status, :string, null: false
      add :total_amount, :decimal, precision: 10, scale: 2, null: false
      add :currency, :string, default: "JPY", null: false
      add :items, :jsonb, default: "[]", null: false
      
      # 追加フィールド
      add :payment_id, :string
      add :shipping_id, :string
      add :cancellation_reason, :text
      
      # タイムスタンプ
      add :confirmed_at, :utc_datetime
      add :payment_processed_at, :utc_datetime
      add :shipped_at, :utc_datetime
      add :delivered_at, :utc_datetime
      add :cancelled_at, :utc_datetime

      timestamps()
    end

    create index(:orders, [:user_id], prefix: "query")
    create index(:orders, [:status], prefix: "query")
    create index(:orders, [:inserted_at], prefix: "query")
  end
end
defmodule Shared.Infrastructure.EventStore.Repo.Migrations.CreateSchemas do
  use Ecto.Migration

  @moduledoc """
  Event Store 専用スキーマを作成するマイグレーション

  ## 責任範囲
  - event_store スキーマのみを管理
  - command/query スキーマは各サービスが管理

  ## 注意事項
  - このマイグレーションは Shared.Infrastructure.EventStore.Repo で実行される
  - 他のサービスのスキーマは各サービスの ensure_schema_exists.exs で作成される
  """

  def up do
    # Event Store 専用スキーマを作成（IF NOT EXISTS により冪等性を保証）
    execute "CREATE SCHEMA IF NOT EXISTS event_store"
  end

  def down do
    # 注意: CASCADE を使用するとスキーマ内のすべてのオブジェクトが削除される
    execute "DROP SCHEMA IF EXISTS event_store CASCADE"
  end
end
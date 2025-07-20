defmodule QueryService.Repo.Migrations.EnsureSchemaExists do
  use Ecto.Migration

  def up do
    # 本番環境とテスト環境でスキーマが存在することを確認
    execute "CREATE SCHEMA IF NOT EXISTS query_service"
  end

  def down do
    # スキーマの削除は行わない（他のテーブルが存在する可能性があるため）
  end
end
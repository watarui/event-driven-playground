defmodule CommandService.Repo.Migrations.EnsureSchemaExists do
  use Ecto.Migration

  @moduledoc """
  Command Service 専用スキーマを作成するマイグレーション

  ## 責任範囲
  - command スキーマのみを管理
  - このスキーマは Command Service 専用

  ## 注意事項
  - このマイグレーションは CommandService.Repo で実行される
  - 必ず最初に実行される必要がある（タイムスタンプ: 20250108000000）
  """

  def up do
    # Command Service 専用スキーマを作成（IF NOT EXISTS により冪等性を保証）
    execute "CREATE SCHEMA IF NOT EXISTS command"
  end

  def down do
    # スキーマの削除は行わない（他のテーブルが存在する可能性があるため）
  end
end
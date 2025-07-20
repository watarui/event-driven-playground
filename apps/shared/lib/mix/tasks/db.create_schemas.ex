defmodule Mix.Tasks.Db.CreateSchemas do
  @moduledoc """
  データベーススキーマを作成する Mix タスク

  ## 使い方

      $ mix db.create_schemas

  このタスクは、アプリケーションで使用するすべてのスキーマを作成します：
  - event_store: イベントストア用
  - command: コマンドサービス用
  - query: クエリサービス用

  スキーマが既に存在する場合は、何もしません（冪等性があります）。
  """

  use Mix.Task

  @shortdoc "データベーススキーマを作成します"

  @impl Mix.Task
  def run(_args) do
    # アプリケーションをロード
    Mix.Task.run("app.config")
    
    # 必要な依存関係を起動
    {:ok, _} = Application.ensure_all_started(:postgrex)
    {:ok, _} = Application.ensure_all_started(:ecto_sql)
    
    # ロギング用の情報表示
    Mix.shell().info("Creating database schemas...")
    
    # 各スキーマを作成
    create_schema(Shared.Infrastructure.EventStore.Repo, "event_store")
    create_schema(CommandService.Repo, "command")
    create_schema(QueryService.Repo, "query")
    
    Mix.shell().info("All schemas created successfully!")
  end

  defp create_schema(repo, schema_name) do
    Mix.shell().info("Creating schema '#{schema_name}'...")
    
    case Ecto.Migrator.with_repo(repo, fn repo ->
      Ecto.Adapters.SQL.query!(repo, "CREATE SCHEMA IF NOT EXISTS #{schema_name}", [])
      {:ok, :schema_created, []}
    end) do
      {:ok, _, _} ->
        Mix.shell().info("✓ Schema '#{schema_name}' created or already exists")
      
      {:error, error} ->
        Mix.shell().error("Failed to create schema '#{schema_name}': #{inspect(error)}")
        raise "Schema creation failed"
    end
  end
end
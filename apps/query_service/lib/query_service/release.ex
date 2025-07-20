defmodule QueryService.Release do
  @moduledoc """
  本番環境でのリリースタスク（マイグレーション実行など）
  """

  @app :query_service

  def migrate do
    load_app()

    # スキーマを作成（マイグレーションとは別のトランザクションで実行）
    ensure_schema_exists()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end

  defp ensure_schema_exists do
    # リポジトリを使用してスキーマを作成
    {:ok, _, _} =
      Ecto.Migrator.with_repo(QueryService.Repo, fn repo ->
        # スキーマ作成はトランザクション外で実行
        Ecto.Adapters.SQL.query!(repo, "CREATE SCHEMA IF NOT EXISTS query", [])
        {:ok, :schema_created, []}
      end)
  end
end

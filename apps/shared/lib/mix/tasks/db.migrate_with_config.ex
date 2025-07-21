defmodule Mix.Tasks.Db.MigrateWithConfig do
  @moduledoc """
  環境変数から接続設定を読み込んでマイグレーションを実行するカスタムタスク
  """
  use Mix.Task

  @shortdoc "Run migrations with environment-based configuration"

  def run(_args) do
    # アプリケーションを起動
    Mix.Task.run("app.start")

    IO.puts("=== Custom Migration Task ===")
    IO.puts("Reading environment variables...")

    # 環境変数から設定を読み込む
    timeout = String.to_integer(System.get_env("DB_TIMEOUT") || "30000")
    connect_timeout = String.to_integer(System.get_env("DB_CONNECT_TIMEOUT") || "30000")
    queue_target = String.to_integer(System.get_env("DB_QUEUE_TARGET") || "50")
    queue_interval = String.to_integer(System.get_env("DB_QUEUE_INTERVAL") || "100")
    pool_size = String.to_integer(System.get_env("POOL_SIZE") || "2")

    IO.puts("Timeout: #{timeout}ms")
    IO.puts("Connect timeout: #{connect_timeout}ms")
    IO.puts("Queue target: #{queue_target}ms")
    IO.puts("Queue interval: #{queue_interval}ms")
    IO.puts("Pool size: #{pool_size}")

    # 各リポジトリの設定を更新
    repos = [
      {Shared.Infrastructure.EventStore.Repo, :shared},
      {CommandService.Repo, :command_service},
      {QueryService.Repo, :query_service}
    ]

    for {repo, app} <- repos do
      IO.puts("\nUpdating configuration for #{inspect(repo)}...")

      # 現在の設定を取得
      current_config = Application.get_env(app, repo, [])

      # 新しい設定をマージ
      new_config =
        Keyword.merge(current_config,
          timeout: timeout,
          connect_timeout: connect_timeout,
          queue_target: queue_target,
          queue_interval: queue_interval,
          pool_size: pool_size,
          init_pool_size: pool_size
        )

      # 設定を更新
      Application.put_env(app, repo, new_config)

      # リポジトリを再起動
      # 注: Ecto 3.x では動的な再起動はサポートされていないため、
      # 設定の更新のみ行う
      IO.puts("Configuration updated for #{inspect(repo)}")
      IO.inspect(new_config, label: "New config", limit: :infinity)
    end

    # マイグレーションを実行
    IO.puts("\n=== Running migrations ===")

    # 各リポジトリのマイグレーションを実行
    for {repo, _app} <- repos do
      IO.puts("\nMigrating #{inspect(repo)}...")
      Ecto.Migrator.run(repo, :up, all: true, log_migrations_sql: true)
    end

    IO.puts("\n=== All migrations completed ===")
  end
end

#!/usr/bin/env elixir
# デバッグスクリプト: データベース設定を確認

IO.puts("\n=== Environment Variables ===")
IO.puts("MIX_ENV: #{System.get_env("MIX_ENV")}")
IO.puts("DATABASE_URL: #{if System.get_env("DATABASE_URL"), do: "SET", else: "NOT SET"}")
IO.puts("POOL_SIZE: #{System.get_env("POOL_SIZE")}")
IO.puts("DB_TIMEOUT: #{System.get_env("DB_TIMEOUT")}")
IO.puts("DB_CONNECT_TIMEOUT: #{System.get_env("DB_CONNECT_TIMEOUT")}")
IO.puts("DB_QUEUE_TARGET: #{System.get_env("DB_QUEUE_TARGET")}")
IO.puts("DB_QUEUE_INTERVAL: #{System.get_env("DB_QUEUE_INTERVAL")}")

IO.puts("\n=== Loading Application ===")
# アプリケーションを起動
{:ok, _} = Application.ensure_all_started(:shared)

IO.puts("\n=== Shared.Config.database_config(:event_store) ===")
config = Shared.Config.database_config(:event_store)
IO.inspect(config, label: "Full config", limit: :infinity)

IO.puts("\n=== Key timeout values ===")
IO.puts("timeout: #{config[:timeout]}")
IO.puts("connect_timeout: #{config[:connect_timeout]}")
IO.puts("queue_target: #{config[:queue_target]}")
IO.puts("queue_interval: #{config[:queue_interval]}")
IO.puts("pool_size: #{config[:pool_size]}")

IO.puts("\n=== Application Environment ===")
repo_config = Application.get_env(:shared, Shared.Infrastructure.EventStore.Repo)
IO.inspect(repo_config, label: "Repo config from Application.get_env", limit: :infinity)
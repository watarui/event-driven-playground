import Config

# テスト環境の設定

# Print only warnings and errors during test
config :logger, level: :warning

# イベントストアのテスト設定
config :shared, Shared.Infrastructure.EventStore.Repo,
  pool: Ecto.Adapters.SQL.Sandbox

# Command Service のテスト設定
config :command_service, CommandService.Repo,
  pool: Ecto.Adapters.SQL.Sandbox

# Query Service のテスト設定
config :query_service, QueryService.Repo,
  pool: Ecto.Adapters.SQL.Sandbox

# Configure ExUnit
ExUnit.configure(
  exclude: [:skip, :pending],
  include: [],
  formatters: [ExUnit.CLIFormatter],
  max_cases: System.schedulers_online() * 2
)

# Start ExUnit
ExUnit.start()

# アプリケーションを起動
{:ok, _} = Application.ensure_all_started(:shared)
{:ok, _} = Application.ensure_all_started(:client_service)

# Load support files
Code.require_file("support/test_helpers.ex", __DIR__)
Code.require_file("support/factory.ex", __DIR__)

# Setup Ecto Sandbox if applicable
if Code.ensure_loaded?(Ecto.Adapters.SQL.Sandbox) do
  # 共有モードに設定
  Ecto.Adapters.SQL.Sandbox.mode(Shared.Infrastructure.EventStore.Repo, :shared)
end

# Configure Mox for mocking
# (Firebase mocking is currently not used)

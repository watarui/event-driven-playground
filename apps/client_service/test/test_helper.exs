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

# Endpoint を手動で起動
ClientServiceWeb.Endpoint.start_link()

# Load support files
Code.require_file("support/test_helpers.ex", __DIR__)

# Firestore を使用しているため、Ecto のサンドボックスモードは不要

# Configure Mox for mocking
# (Firebase mocking is currently not used)

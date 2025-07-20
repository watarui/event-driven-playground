# Configure ExUnit
ExUnit.configure(
  exclude: [:skip, :pending],
  include: [],
  formatters: [ExUnit.CLIFormatter],
  max_cases: System.schedulers_online() * 2
)

# Start ExUnit
ExUnit.start()

# Load support files
Code.require_file("support/test_helpers.ex", __DIR__)
Code.require_file("support/factory.ex", __DIR__)

# Setup Ecto Sandbox if applicable
if Code.ensure_loaded?(Ecto.Adapters.SQL.Sandbox) do
  Ecto.Adapters.SQL.Sandbox.mode(Shared.Infrastructure.EventStore.Repo, :manual)
end

# Configure Mox for mocking
if Code.ensure_loaded?(Mox) do
  Mox.defmock(ClientService.MockFirebaseClient, for: ClientService.Auth.FirebaseClient)
  Application.put_env(:client_service, :firebase_client, ClientService.MockFirebaseClient)
end

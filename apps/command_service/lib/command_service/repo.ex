defmodule CommandService.Repo do
  use Ecto.Repo,
    otp_app: :command_service,
    adapter: Ecto.Adapters.Postgres

  @impl true
  def init(_type, config) do
    config = Keyword.put(config, :migration_default_prefix, "command")
    {:ok, config}
  end
end

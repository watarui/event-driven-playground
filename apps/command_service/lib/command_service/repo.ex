defmodule CommandService.Repo do
  use Ecto.Repo,
    otp_app: :command_service,
    adapter: Ecto.Adapters.Postgres

  @impl true
  def init(_type, config) do
    # Merge defaults with provided config to preserve runtime values
    defaults = [
      migration_default_prefix: "command"
    ]
    
    config = Keyword.merge(defaults, config)
    {:ok, config}
  end
end

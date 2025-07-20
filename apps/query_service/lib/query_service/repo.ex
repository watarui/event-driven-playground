defmodule QueryService.Repo do
  use Ecto.Repo,
    otp_app: :query_service,
    adapter: Ecto.Adapters.Postgres

  @impl true
  def init(_type, config) do
    config = Keyword.put(config, :migration_default_prefix, "query")
    {:ok, config}
  end
end

defmodule QueryService.Repo do
  use Ecto.Repo,
    otp_app: :query_service,
    adapter: Ecto.Adapters.Postgres
end

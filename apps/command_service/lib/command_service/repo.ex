defmodule CommandService.Repo do
  use Ecto.Repo,
    otp_app: :command_service,
    adapter: Ecto.Adapters.Postgres
end

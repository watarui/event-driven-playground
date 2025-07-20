defmodule CommandService.Repo do
  use Ecto.Repo,
    otp_app: :command_service,
    adapter: Ecto.Adapters.Postgres

  # 追加の設定は不要
end

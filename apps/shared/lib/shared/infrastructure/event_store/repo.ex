defmodule Shared.Infrastructure.EventStore.Repo do
  @moduledoc """
  イベントストア用のリポジトリ
  """

  use Ecto.Repo,
    otp_app: :shared,
    adapter: Ecto.Adapters.Postgres

  # SQL クエリのログ出力
  @impl true
  def init(_, config) do
    config =
      config
      |> Keyword.put(:log, :debug)
      |> Keyword.put(:migration_default_prefix, "event_store")

    {:ok, config}
  end
end

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
    # Merge defaults with provided config to preserve runtime values
    defaults = [
      log: :debug,
      migration_default_prefix: "event_store"
    ]
    
    config = Keyword.merge(defaults, config)

    {:ok, config}
  end
end

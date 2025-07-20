defmodule Shared.Infrastructure.EventStore.Repo do
  @moduledoc """
  イベントストア用のリポジトリ
  """

  use Ecto.Repo,
    otp_app: :shared,
    adapter: Ecto.Adapters.Postgres

  # SQL クエリのログ出力
  def init(_, config) do
    config = Keyword.put(config, :log, :debug)
    {:ok, config}
  end
end

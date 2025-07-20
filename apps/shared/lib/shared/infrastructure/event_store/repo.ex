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
    
    # テスト環境と本番環境では event_store スキーマを使用
    config = 
      if Mix.env() in [:test, :prod] do
        Keyword.put(config, :after_connect, {Ecto.Adapters.Postgres, :set_search_path, ["event_store"]})
      else
        config
      end
    
    {:ok, config}
  end
end

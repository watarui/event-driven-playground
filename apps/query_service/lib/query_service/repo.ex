defmodule QueryService.Repo do
  use Ecto.Repo,
    otp_app: :query_service,
    adapter: Ecto.Adapters.Postgres

  def init(_, config) do
    # テスト環境と本番環境では query_service スキーマを使用
    config = 
      if Mix.env() in [:test, :prod] do
        Keyword.put(config, :after_connect, {Ecto.Adapters.Postgres, :set_search_path, ["query_service"]})
      else
        config
      end
    
    {:ok, config}
  end
end

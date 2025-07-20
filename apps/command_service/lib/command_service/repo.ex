defmodule CommandService.Repo do
  use Ecto.Repo,
    otp_app: :command_service,
    adapter: Ecto.Adapters.Postgres

  def init(_, config) do
    # テスト環境と本番環境では command_service スキーマを使用
    config = 
      if Mix.env() in [:test, :prod] do
        Keyword.put(config, :after_connect, {Ecto.Adapters.Postgres, :set_search_path, ["command_service"]})
      else
        config
      end
    
    {:ok, config}
  end
end

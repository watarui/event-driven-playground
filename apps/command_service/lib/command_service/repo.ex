defmodule CommandService.Repo do
  use Ecto.Repo,
    otp_app: :command_service,
    adapter: Ecto.Adapters.Postgres

  def init(_, config) do
    # schema_prefix が設定されている場合はサーチパスを設定
    config = 
      if schema_prefix = Keyword.get(config, :schema_prefix) do
        Keyword.put(config, :after_connect, {Ecto.Adapters.Postgres, :set_search_path, [schema_prefix]})
      else
        config
      end
    
    {:ok, config}
  end
end

defmodule Shared.Infrastructure.EventStore.Repo do
  @moduledoc """
  イベントストア用のリポジトリ
  """

  use Ecto.Repo,
    otp_app: :shared,
    adapter: Ecto.Adapters.Postgres

  # SQL クエリのログ出力とスキーマ設定
  def init(_, config) do
    config = Keyword.put(config, :log, :debug)
    
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

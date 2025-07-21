defmodule QueryServiceWeb.Endpoint do
  @moduledoc """
  Query Service の HTTP エンドポイント
  """
  use Plug.Builder

  plug(QueryServiceWeb)

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end

  def start_link(_opts \\ []) do
    # 開発環境用のポート設定
    default_port = if Mix.env() == :dev, do: "4082", else: "8080"
    port = System.get_env("PORT", default_port) |> String.to_integer()

    require Logger
    Logger.info("Starting QueryService HTTP endpoint on port #{port}")

    Plug.Cowboy.http(__MODULE__, [], port: port)
  end
end

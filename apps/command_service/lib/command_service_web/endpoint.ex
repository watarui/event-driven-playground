defmodule CommandServiceWeb.Endpoint do
  @moduledoc """
  Command Service の HTTP エンドポイント
  """
  use Plug.Builder

  plug(CommandServiceWeb)

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end

  def start_link(_opts \\ []) do
    # 開発環境用のポート設定
    default_port = if Mix.env() == :dev, do: "4081", else: "8080"
    port = System.get_env("COMMAND_SERVICE_PORT", default_port) |> String.to_integer()

    require Logger
    Logger.info("Starting CommandService HTTP endpoint on port #{port}")

    Plug.Cowboy.http(__MODULE__, [], port: port)
  end
end

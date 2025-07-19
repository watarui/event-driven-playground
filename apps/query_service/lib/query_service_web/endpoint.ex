defmodule QueryServiceWeb.Endpoint do
  @moduledoc """
  Query Service の HTTP エンドポイント
  """
  use Plug.Builder

  plug QueryServiceWeb
  
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end
  
  def start_link(_opts \\ []) do
    port = System.get_env("PORT", "8080") |> String.to_integer()
    
    require Logger
    Logger.info("Starting QueryService HTTP endpoint on port #{port}")
    
    Plug.Cowboy.http(__MODULE__, [], port: port)
  end
end
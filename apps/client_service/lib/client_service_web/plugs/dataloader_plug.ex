defmodule ClientServiceWeb.Plugs.DataloaderPlug do
  @moduledoc """
  GraphQL リクエストに Dataloader を追加するプラグ
  """

  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    # Dataloader はスキーマで管理するため、ここでは何もしない
    conn
  end
end

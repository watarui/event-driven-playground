defmodule ClientService.Auth.EnsureAuthenticatedPlug do
  @moduledoc """
  認証が必要なエンドポイントで使用するプラグ
  認証されていない場合は 401 エラーを返す
  """
  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.assigns[:is_authenticated] do
      conn
    else
      Logger.warning("Unauthenticated request blocked")

      conn
      |> put_status(:unauthorized)
      |> put_resp_content_type("application/json")
      |> send_resp(
        401,
        Jason.encode!(%{
          error: "Unauthorized",
          message: "Authentication required"
        })
      )
      |> halt()
    end
  end
end

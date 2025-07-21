defmodule ClientService.Auth.EnsureAuthenticatedPlug do
  @moduledoc """
  認証が必要なエンドポイントで使用するプラグ
  認証されていない場合は 401 エラーを返す
  """
  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, opts) do
    if conn.assigns[:current_user] do
      conn
    else
      Logger.warning("Unauthenticated request blocked")
      
      error_handler = opts[:error_handler]
      
      if error_handler do
        error_handler.auth_error(conn, {:unauthenticated, :unauthenticated}, opts)
      else
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
end

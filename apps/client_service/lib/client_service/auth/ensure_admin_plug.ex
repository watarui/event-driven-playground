defmodule ClientService.Auth.EnsureAdminPlug do
  @moduledoc """
  管理者権限が必要なエンドポイントで使用するプラグ
  管理者でない場合は 403 エラーを返す
  """
  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    cond do
      !conn.assigns[:is_authenticated] ->
        Logger.warning("Unauthenticated request to admin endpoint")

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

      !conn.assigns[:is_admin] ->
        Logger.warning(
          "Non-admin user attempted to access admin endpoint: #{conn.assigns[:current_user][:user_id]}"
        )

        conn
        |> put_status(:forbidden)
        |> put_resp_content_type("application/json")
        |> send_resp(
          403,
          Jason.encode!(%{
            error: "Forbidden",
            message: "Admin privileges required"
          })
        )
        |> halt()

      true ->
        conn
    end
  end
end

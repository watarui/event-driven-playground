defmodule ClientService.Auth.EnsureAdminPlug do
  @moduledoc """
  管理者権限が必要なエンドポイントで使用するプラグ
  管理者でない場合は 403 エラーを返す
  """
  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, opts) do
    current_user = conn.assigns[:current_user]
    error_handler = opts[:error_handler]
    
    cond do
      is_nil(current_user) ->
        Logger.warning("Unauthenticated request to admin endpoint")
        
        if error_handler && is_atom(error_handler) do
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

      current_user[:role] != :admin ->
        Logger.warning(
          "Non-admin user attempted to access admin endpoint: #{current_user[:user_id] || current_user[:id]}"
        )
        
        if error_handler && is_atom(error_handler) do
          error_handler.auth_error(conn, {:unauthorized, :forbidden}, opts)
        else
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
        end

      true ->
        conn
    end
  end
end

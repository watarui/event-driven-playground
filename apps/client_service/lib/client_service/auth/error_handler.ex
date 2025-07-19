defmodule ClientService.Auth.ErrorHandler do
  @moduledoc """
  認証エラーのハンドリング
  """
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]
  require Logger

  @behaviour Guardian.Plug.ErrorHandler

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, {type, reason}, _opts) do
    Logger.error("Auth error occurred - Type: #{inspect(type)}, Reason: #{inspect(reason)}")
    
    body =
      Jason.encode!(%{
        error: to_string(type),
        message: error_message(type)
      })

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, body)
  end

  defp error_message(:invalid_token), do: "Invalid authentication token"
  defp error_message(:token_expired), do: "Authentication token has expired"
  defp error_message(:unauthenticated), do: "Authentication required"
  defp error_message(:no_resource_found), do: "Resource not found"
  defp error_message(_), do: "Authentication error"
end

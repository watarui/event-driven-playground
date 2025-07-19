defmodule ClientService.Auth.FirebasePlug do
  @moduledoc """
  Firebase Authentication のトークンを検証するプラグ
  Guardian を使わずに直接 Firebase トークンを処理
  """
  import Plug.Conn
  require Logger
  
  alias ClientService.Auth.FirebaseAuth

  def init(opts), do: opts

  def call(conn, _opts) do
    Logger.info("FirebasePlug called")
    
    with {:ok, token} <- get_token_from_header(conn),
         {:ok, user_info} <- FirebaseAuth.verify_token(token) do
      Logger.info("Firebase authentication successful for user: #{user_info.user_id}")
      
      conn
      |> assign(:current_user, user_info)
      |> assign(:user_signed_in?, true)
    else
      {:error, :no_token} ->
        Logger.debug("No authentication token provided")
        
        conn
        |> assign(:current_user, nil)
        |> assign(:user_signed_in?, false)
        
      {:error, reason} ->
        Logger.debug("Firebase authentication failed: #{inspect(reason)}")
        # 認証失敗時も接続を継続し、未認証ユーザーとして扱う
        conn
        |> assign(:current_user, nil)
        |> assign(:user_signed_in?, false)
    end
  end

  defp get_token_from_header(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> 
        Logger.debug("Token extracted from Authorization header")
        {:ok, token}
      [_] -> 
        Logger.debug("Invalid Authorization header format")
        {:error, :invalid_header}
      [] -> 
        Logger.debug("No Authorization header found")
        {:error, :no_token}
    end
  end
end
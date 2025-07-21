defmodule ClientService.Auth.AuthPlug do
  @moduledoc """
  認証情報を GraphQL コンテキストに追加するプラグ
  """
  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    Logger.info("AuthPlug.call - checking current resource")
    current_resource = Guardian.Plug.current_resource(conn)
    Logger.info("Current resource: #{inspect(current_resource)}")

    case current_resource do
      nil ->
        Logger.info("No current resource found, checking token directly")

        # Guardian.Plug がリソースをロードできなかった場合、直接トークンを検証
        token = get_token_from_header(conn)

        if token do
          Logger.info("Found token, verifying with Firebase")

          case ClientService.Auth.Guardian.verify_token(token) do
            {:ok, auth_info} ->
              Logger.info("Token verified successfully")
              # 認証情報を assigns と Absinthe コンテキストに追加
              conn
              |> assign(:current_user, auth_info)
              |> assign(:user_signed_in?, true)
              |> Absinthe.Plug.put_options(
                context: %{
                  current_user: auth_info,
                  is_authenticated: true,
                  is_admin: auth_info.is_admin
                }
              )

            {:error, reason} ->
              Logger.error("Token verification failed: #{inspect(reason)}")
              conn
              |> assign(:current_user, nil)
              |> assign(:user_signed_in?, false)
          end
        else
          Logger.info("No token found in header")
          conn
          |> assign(:current_user, nil)
          |> assign(:user_signed_in?, false)
        end

      _user ->
        Logger.info("Current resource found, verifying token")
        # Authorization ヘッダーからトークンを取得
        token = get_token_from_header(conn)

        case ClientService.Auth.Guardian.verify_token(token) do
          {:ok, auth_info} ->
            Logger.info("Token verified successfully for user")
            # 認証情報を assigns と Absinthe コンテキストに追加
            conn
            |> assign(:current_user, auth_info)
            |> assign(:user_signed_in?, true)
            |> Absinthe.Plug.put_options(
              context: %{
                current_user: auth_info,
                is_authenticated: true,
                is_admin: auth_info.is_admin
              }
            )

          {:error, reason} ->
            Logger.error("Token verification failed: #{inspect(reason)}")
            conn
            |> assign(:current_user, nil)
            |> assign(:user_signed_in?, false)
        end
    end
  end

  defp get_token_from_header(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> token
      _ -> nil
    end
  end
end

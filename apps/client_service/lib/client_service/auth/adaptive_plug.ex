defmodule ClientService.Auth.AdaptivePlug do
  @moduledoc """
  環境に応じて認証方式を切り替えるアダプティブ認証プラグ

  - 開発環境（:disabled）: 自動的に admin ユーザーを割り当て
  - 本番環境（:firebase）: Firebase 認証を使用
  """
  import Plug.Conn
  require Logger

  alias ClientService.Auth.FirebasePlug

  def init(opts), do: opts

  def call(conn, opts) do
    auth_mode = Application.get_env(:client_service, :auth_mode, :firebase)

    Logger.debug("AdaptivePlug: auth_mode = #{inspect(auth_mode)}")

    case auth_mode do
      :disabled ->
        # 開発環境: 自動的に admin ユーザーを割り当て
        Logger.info("AdaptivePlug: Auth disabled in development mode")
        assign_dev_user(conn)

      :firebase ->
        # 本番環境: Firebase 認証を使用
        Logger.info("AdaptivePlug: Using Firebase authentication")
        FirebasePlug.call(conn, opts)

      mode ->
        # 未知の認証モード
        Logger.error("AdaptivePlug: Unknown auth mode: #{inspect(mode)}")

        conn
        |> send_resp(500, "Invalid authentication configuration")
        |> halt()
    end
  end

  defp assign_dev_user(conn) do
    dev_user = %{
      user_id: "dev-admin-user",
      email: "admin@localhost",
      name: "Development Admin",
      role: :admin,
      user_role: :admin,
      # Firebase 互換のフィールド
      uid: "dev-admin-user",
      email_verified: true
    }

    conn
    |> assign(:current_user, dev_user)
    |> assign(:user_signed_in?, true)
  end
end

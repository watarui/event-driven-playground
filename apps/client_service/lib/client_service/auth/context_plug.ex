defmodule ClientService.Auth.ContextPlug do
  @moduledoc """
  認証情報を GraphQL コンテキストに追加するプラグ
  """
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    Logger.info("ContextPlug called")

    # 既存のコンテキストを取得（Routerで設定されたものがあれば）
    existing_context = conn.private[:absinthe][:context] || %{}

    # 認証情報を追加
    auth_context = %{
      current_user: conn.assigns[:current_user],
      is_authenticated: conn.assigns[:user_signed_in?] || false,
      is_admin: admin?(conn.assigns[:current_user])
    }

    # 既存のコンテキストと認証情報をマージ
    merged_context = Map.merge(existing_context, auth_context)

    Logger.debug("GraphQL context: #{inspect(merged_context)}")

    # Absinthe 用のコンテキストを設定
    Absinthe.Plug.put_options(conn, context: merged_context)
  end

  defp admin?(nil), do: false
  defp admin?(%{is_admin: true}), do: true
  defp admin?(_), do: false
end

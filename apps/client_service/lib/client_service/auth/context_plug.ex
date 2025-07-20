defmodule ClientService.Auth.ContextPlug do
  @moduledoc """
  認証情報を GraphQL コンテキストに追加するプラグ
  """
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    Logger.info("ContextPlug called")

    context = %{
      current_user: conn.assigns[:current_user],
      is_authenticated: conn.assigns[:user_signed_in?] || false,
      is_admin: admin?(conn.assigns[:current_user])
    }

    Logger.debug("GraphQL context: #{inspect(context)}")

    # Absinthe 用のコンテキストを設定
    Absinthe.Plug.put_options(conn, context: context)
  end

  defp admin?(nil), do: false
  defp admin?(%{is_admin: true}), do: true
  defp admin?(_), do: false
end

defmodule ClientServiceWeb.Plugs.AbsintheContextPlug do
  @moduledoc """
  Absinthe GraphQL のコンテキストを構築するプラグ
  認証情報と PubSub の両方を含むコンテキストを作成する
  """

  @behaviour Plug
  require Logger

  def init(opts), do: opts

  def call(conn, opts) do
    pubsub = Keyword.get(opts, :pubsub, ClientService.PubSub)

    # 認証情報を含むコンテキストを構築
    context = %{
      # PubSub 設定
      pubsub: pubsub,
      # 認証情報
      current_user: conn.assigns[:current_user],
      is_authenticated: conn.assigns[:user_signed_in?] || false,
      is_admin: admin?(conn.assigns[:current_user])
    }

    Logger.debug("AbsintheContextPlug: Building context: #{inspect(context)}")

    # Absinthe 用のコンテキストを設定
    Absinthe.Plug.put_options(conn, context: context)
  end

  defp admin?(nil), do: false
  defp admin?(%{is_admin: true}), do: true
  defp admin?(_), do: false
end

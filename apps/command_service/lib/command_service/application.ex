defmodule CommandService.Application do
  @moduledoc """
  Command Service アプリケーションのスーパーバイザー
  """

  use Application

  @impl true
  def start(_type, _args) do
    # クラスタリングの初期化
    connect_to_cluster()

    # 基本的な子プロセス
    children = [
      # コマンドバス
      CommandService.Infrastructure.CommandBus,
      # コマンドリスナー（PubSub経由でコマンドを受信）
      CommandService.Infrastructure.CommandListener,
      # HTTP エンドポイント（ヘルスチェック用）
      CommandServiceWeb.Endpoint
    ]

    # PostgreSQL 使用時のみ Repo を起動
    children =
      if Shared.Config.database_adapter() != :firestore do
        [{CommandService.Repo, []} | children]
      else
        children
      end

    opts = [strategy: :one_for_one, name: CommandService.Supervisor]

    require Logger
    Logger.info("Starting Command Service with PubSub listener on node: #{node()}")

    Supervisor.start_link(children, opts)
  end

  defp connect_to_cluster do
    require Logger

    # 他のノードに接続を試みる
    nodes = [:"query@127.0.0.1", :"client@127.0.0.1"]

    Enum.each(nodes, fn node ->
      case Node.connect(node) do
        true ->
          Logger.info("Connected to node: #{node}")

        false ->
          Logger.debug("Could not connect to node: #{node} (may not be started yet)")

        :ignored ->
          Logger.debug("Connection to node #{node} was ignored")
      end
    end)

    Logger.info("Current connected nodes: #{inspect(Node.list())}")
  end
end

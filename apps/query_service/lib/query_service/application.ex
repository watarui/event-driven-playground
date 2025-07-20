defmodule QueryService.Application do
  @moduledoc """
  Query Service アプリケーションのスーパーバイザー
  """

  use Application

  @impl true
  def start(_type, _args) do
    # クラスタリングの初期化
    connect_to_cluster()

    children = [
      # Ecto リポジトリ
      QueryService.Repo,
      # キャッシュ
      QueryService.Infrastructure.Cache,
      # クエリバス
      QueryService.Infrastructure.QueryBus,
      # プロジェクションマネージャー
      QueryService.Infrastructure.ProjectionManager,
      # クエリリスナー（PubSub経由でクエリを受信）
      QueryService.Infrastructure.QueryListener
    ]
    
    # テスト環境以外では HTTP エンドポイントを起動
    children = 
      if Mix.env() != :test do
        children ++ [QueryServiceWeb.Endpoint]
      else
        children
      end

    opts = [strategy: :one_for_one, name: QueryService.Supervisor]

    require Logger
    Logger.info("Starting Query Service with PubSub listener on node: #{node()}")

    Supervisor.start_link(children, opts)
  end

  defp connect_to_cluster do
    require Logger

    # 他のノードに接続を試みる
    nodes = [:"command@127.0.0.1", :"client@127.0.0.1"]

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

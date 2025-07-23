defmodule ClientService.Application do
  @moduledoc """
  Client Service アプリケーション

  GraphQL API ゲートウェイとして機能します
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Telemetry
      ClientServiceWeb.Telemetry,
      # Cache for Firebase public keys
      {Cachex, name: :firebase_keys},
      # PubSub
      {Phoenix.PubSub, name: ClientService.PubSub},
      # Node Connector (他のノードへの接続を管理)
      # Cloud Run では分散Erlangを使用しないため無効化
      # ClientService.Infrastructure.NodeConnector,
      # Remote Command Bus (PubSub経由でコマンドを送信)
      ClientService.Infrastructure.RemoteCommandBus,
      # Remote Query Bus (PubSub経由でクエリを送信)
      ClientService.Infrastructure.RemoteQueryBus,
      # Saga Executor (Sagaパターンの実行)
      Shared.Infrastructure.Saga.SagaExecutor,
      # PubSub Broadcaster (リアルタイムモニタリング用)
      ClientService.PubSubBroadcaster,
      # Endpoint
      ClientServiceWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ClientService.Supervisor]

    require Logger
    Logger.info("Starting Client Service with GraphQL API on node: #{node()}")

    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ClientServiceWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

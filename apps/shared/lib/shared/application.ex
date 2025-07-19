defmodule Shared.Application do
  @moduledoc """
  Shared アプリケーションのスーパーバイザー
  """

  use Application

  @impl true
  def start(_type, _args) do
    # OpenTelemetry を初期化
    Shared.Telemetry.Setup.init()

    children = [
      # HTTPクライアント
      {Finch, name: Shared.Finch},
      # PubSub (Cloud Run では必須)
      {Phoenix.PubSub, name: :event_bus_pubsub},
      # イベントストアのリポジトリ
      Shared.Infrastructure.EventStore.Repo,
      # イベントバス（環境に応じて自動選択）
      # get_event_bus_module(), # PubSub を直接起動するためコメントアウト
      # アグリゲートバージョンキャッシュ
      Shared.Infrastructure.EventStore.AggregateVersionCache,
      # サーキットブレーカー
      Shared.Infrastructure.Resilience.CircuitBreakerSupervisor,
      # デッドレターキュー
      Shared.Infrastructure.DeadLetterQueue,
      # べき等性ストア
      Shared.Infrastructure.Idempotency.IdempotencyStore,
      # Sagaコンポーネント
      Shared.Infrastructure.Saga.SagaExecutor,
      # サガメトリクス
      Shared.Telemetry.SagaMetrics,
      # Event Sourcing 改善
      {Shared.Infrastructure.EventStore.EventArchiver,
       [archive_interval: :timer.hours(24), retention_days: 90]}
    ]

    opts = [strategy: :one_for_one, name: Shared.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

defmodule Shared.Application do
  @moduledoc """
  Shared アプリケーションのスーパーバイザー
  """

  use Application

  @impl true
  def start(_type, _args) do
    # OpenTelemetry を初期化
    Shared.Telemetry.Setup.init()

    # 基本的な子プロセス
    children = [
      # HTTPクライアント
      {Finch, name: Shared.Finch},
      # PubSub (Cloud Run では必須)
      {Phoenix.PubSub, name: :event_bus_pubsub}
    ]

    # Goth (Google認証) - Firestore 使用時のみ
    children =
      if Shared.Config.database_adapter() == :firestore && !using_firestore_emulator?() do
        children ++ [{Goth, name: Shared.Goth}]
      else
        children
      end

    # Firestore 使用時は Ecto 関連のプロセスを起動しない

    # 共通のプロセス
    children =
      children ++
        [
          # サガメトリクス
          Shared.Telemetry.SagaMetrics
        ]

    # サーキットブレーカーをテスト環境では起動しない
    children =
      if Application.get_env(:shared, :start_circuit_breaker, true) do
        # サーキットブレーカー
        children ++ [Shared.Infrastructure.Resilience.CircuitBreakerSupervisor]
      else
        children
      end

    opts = [strategy: :one_for_one, name: Shared.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # エミュレータ使用中かチェック（起動時に使用）
  defp using_firestore_emulator? do
    System.get_env("FIRESTORE_EMULATOR_HOST") != nil ||
      Application.get_env(:shared, :firestore_emulator_host) != nil
  end
end

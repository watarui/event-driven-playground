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
      {Finch, name: Shared.Finch}
    ]

    # Goth (Google認証) - Firestore または Google Cloud PubSub 使用時
    # EventBus より前に起動する必要がある
    children =
      if should_start_goth?() do
        children ++ [{Goth, name: Shared.Goth}]
      else
        children
      end

    # EventBus (環境に応じて PG2 または Google Cloud PubSub を使用)
    # Goth の後に起動する必要がある
    children = children ++ [Shared.Infrastructure.EventBus.child_spec([])]

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

  # Goth を起動すべきか判定
  defp should_start_goth? do
    # Firestore を使用していてエミュレータを使用していない場合
    firestore_needs_goth = Shared.Config.database_adapter() == :firestore && !using_firestore_emulator?()
    
    # 本番環境で Google Cloud PubSub を使用する場合
    pubsub_needs_goth = System.get_env("MIX_ENV") == "prod" && System.get_env("GOOGLE_CLOUD_PROJECT") != nil
    
    # テスト環境では Goth を無効化
    test_env = System.get_env("MIX_ENV") == "test"
    
    !test_env && (firestore_needs_goth || pubsub_needs_goth)
  end
end

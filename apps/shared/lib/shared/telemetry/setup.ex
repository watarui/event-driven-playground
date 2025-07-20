defmodule Shared.Telemetry.Setup do
  @moduledoc """
  OpenTelemetry のセットアップ
  環境に応じて適切なエクスポーターを設定します
  """

  require Logger

  @doc """
  OpenTelemetry を初期化する
  """
  def init do
    # 環境に応じた設定
    Shared.Telemetry.CloudSetup.setup()

    # 基本的なテレメトリイベントをアタッチ
    attach_basic_handlers()

    # Google Cloud 環境の場合は追加のハンドラーを設定
    if System.get_env("K_SERVICE") do
      setup_cloud_handlers()
    end

    Logger.info("Telemetry initialized for #{environment()}")
  end

  defp attach_basic_handlers do
    # CQRS イベントのみを簡潔に追跡
    :telemetry.attach_many(
      "event-driven-playground-telemetry",
      [
        # コマンド実行
        [:event_driven_playground, :command, :dispatched],
        [:event_driven_playground, :command, :completed],
        [:event_driven_playground, :command, :failed],

        # クエリ実行
        [:event_driven_playground, :query, :executed],
        [:event_driven_playground, :query, :failed],

        # イベント発行
        [:event_driven_playground, :event, :stored],
        [:event_driven_playground, :event, :published],

        # Saga 実行
        [:event_driven_playground, :saga, :started],
        [:event_driven_playground, :saga, :completed],
        [:event_driven_playground, :saga, :failed],

        # サーキットブレーカー
        [:event_driven_playground, :circuit_breaker, :opened],
        [:event_driven_playground, :circuit_breaker, :closed]
      ],
      &handle_event/4,
      nil
    )
  end

  defp handle_event(event_name, measurements, metadata, _config) do
    # 単純なログ出力のみ（詳細なトレーシングは OpenTelemetry が自動的に処理）
    Logger.debug("Telemetry event: #{inspect(event_name)}",
      measurements: measurements,
      metadata: metadata
    )

    :ok
  end

  defp environment do
    cond do
      System.get_env("K_SERVICE") -> "google_cloud_run"
      Mix.env() == :prod -> "production"
      true -> "development"
    end
  end

  defp setup_cloud_handlers do
    # Google Cloud 環境用の追加ハンドラー
    # OpenTelemetry が自動的に Cloud Trace にエクスポートするため、
    # 追加のカスタムメトリクスは最小限にする

    # 重要なビジネスメトリクスのみを OpenTelemetry のスパンに追加
    :telemetry.attach_many(
      "event-driven-playground-cloud-metrics",
      [
        # ビジネスメトリクス
        [:event_driven_playground, :order, :created],
        [:event_driven_playground, :order, :confirmed],
        [:event_driven_playground, :order, :cancelled],
        [:event_driven_playground, :payment, :processed],
        [:event_driven_playground, :inventory, :reserved]
      ],
      &handle_cloud_event/4,
      nil
    )
  end

  defp handle_cloud_event(event_name, measurements, _metadata, _config) do
    # OpenTelemetry の現在のスパンに属性を追加
    :otel_span.set_attributes([
      {"business.event", event_name |> List.last() |> to_string()},
      {"business.value", Map.get(measurements, :value, 0)}
    ])

    :ok
  end
end

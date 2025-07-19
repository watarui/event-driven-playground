defmodule ClientService.GraphQL.Types.Health do
  @moduledoc """
  ヘルスチェック関連の GraphQL 型定義
  """

  use Absinthe.Schema.Notation

  @desc "ヘルスステータス"
  enum :health_status do
    value(:healthy, description: "正常")
    value(:degraded, description: "一部機能低下")
    value(:unhealthy, description: "異常")
  end

  @desc "個別のヘルスチェック結果"
  object :health_check_result do
    field(:name, non_null(:string), description: "チェック名")
    field(:status, non_null(:health_status), description: "ステータス")
    field(:message, non_null(:string), description: "メッセージ")
    field(:details, :json, description: "詳細情報")
    field(:duration_ms, non_null(:integer), description: "実行時間（ミリ秒）")
  end

  @desc "ヘルスレポート"
  object :health_report do
    field(:status, non_null(:health_status), description: "全体ステータス")
    field(:timestamp, non_null(:datetime), description: "チェック実行時刻")
    field(:checks, non_null(list_of(non_null(:health_check_result))), description: "個別チェック結果")
    field(:version, non_null(:string), description: "アプリケーションバージョン")
    field(:node, non_null(:string), description: "ノード名")
  end

  @desc "メモリ情報"
  object :memory_info do
    field(:total_mb, non_null(:float), description: "総メモリ使用量（MB）")
    field(:process_mb, non_null(:float), description: "プロセスメモリ使用量（MB）")
    field(:binary_mb, non_null(:float), description: "バイナリメモリ使用量（MB）")
    field(:ets_mb, non_null(:float), description: "ETSメモリ使用量（MB）")
    field(:process_count, non_null(:integer), description: "プロセス数")
    field(:port_count, non_null(:integer), description: "ポート数")
  end

  @desc "サービス状態"
  enum :service_status do
    value(:running, description: "稼働中")
    value(:not_started, description: "未起動")
    value(:dead, description: "停止")
    value(:error, description: "エラー")
  end

  @desc "サーキットブレーカー状態"
  enum :circuit_breaker_status do
    value(:closed, description: "正常（閉）")
    value(:open, description: "異常（開）")
    value(:half_open, description: "復旧試行中（半開）")
  end
end

# モニタリングガイド

Elixir CQRS/ES プロジェクトの包括的なモニタリングとオブザーバビリティのガイドです。

## 📋 目次

- [概要](#概要)
- [モニタリングスタック](#モニタリングスタック)
- [メトリクス収集](#メトリクス収集)
- [分散トレーシング](#分散トレーシング)
- [ログ管理](#ログ管理)
- [ダッシュボード](#ダッシュボード)
- [アラート設定](#アラート設定)
- [パフォーマンス分析](#パフォーマンス分析)

## 概要

本プロジェクトは以下のモニタリングツールを統合しています：

- **Prometheus**: メトリクス収集とストレージ
- **Grafana**: ダッシュボードとビジュアライゼーション
- **Jaeger**: 分散トレーシング
- **OpenTelemetry**: 統一されたオブザーバビリティ API
- **Phoenix LiveDashboard**: Elixir アプリケーションの内部監視

## モニタリングスタック

### アーキテクチャ

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Elixir    │────▶│ OpenTelemetry│────▶│   Jaeger    │
│  Services   │     │  Collector   │     │   (Traces)  │
└─────────────┘     └─────────────┘     └─────────────┘
       │                                          │
       │ Metrics                                  │
       ▼                                          │
┌─────────────┐     ┌─────────────┐              │
│ Prometheus  │────▶│   Grafana   │◀─────────────┘
│             │     │             │
└─────────────┘     └─────────────┘
```

### アクセス URL

- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **Jaeger UI**: http://localhost:16686
- **Phoenix LiveDashboard**: http://localhost:4000/dashboard

## メトリクス収集

### Telemetry メトリクス

プロジェクトは以下の主要メトリクスを収集します：

#### アプリケーションメトリクス

```elixir
# apps/shared/lib/shared/telemetry/metrics.ex
def metrics do
  [
    # コマンド処理
    counter("command.dispatched.count", tags: [:command_type]),
    summary("command.processing.duration", tags: [:command_type], unit: {:native, :millisecond}),

    # イベント処理
    counter("event.stored.count", tags: [:event_type]),
    summary("event.processing.duration", tags: [:event_type], unit: {:native, :millisecond}),

    # クエリ処理
    counter("query.executed.count", tags: [:query_type]),
    summary("query.execution.duration", tags: [:query_type], unit: {:native, :millisecond}),

    # Saga メトリクス
    counter("saga.started.count", tags: [:saga_type]),
    counter("saga.completed.count", tags: [:saga_type, :status]),
    summary("saga.duration", tags: [:saga_type], unit: {:native, :second})
  ]
end
```

#### システムメトリクス

```elixir
# VM メトリクス
summary("vm.memory.total", unit: {:byte, :megabyte}),
summary("vm.total_run_queue_lengths.total"),
summary("vm.total_run_queue_lengths.cpu"),
summary("vm.total_run_queue_lengths.io"),

# データベースメトリクス
summary("repo.query.total_time", unit: {:native, :millisecond}),
summary("repo.query.decode_time", unit: {:native, :millisecond}),
summary("repo.query.query_time", unit: {:native, :millisecond}),
summary("repo.query.queue_time", unit: {:native, :millisecond})
```

### カスタムメトリクスの追加

新しいメトリクスを追加する方法：

```elixir
# イベントの発行
:telemetry.execute(
  [:my_app, :custom, :event],
  %{duration: System.monotonic_time() - start_time},
  %{status: :ok, user_id: user_id}
)

# メトリクスの定義
counter("my_app.custom.event.count", tags: [:status]),
summary("my_app.custom.event.duration", tags: [:status], unit: {:native, :millisecond})
```

## 分散トレーシング

### OpenTelemetry 設定

```elixir
# config/runtime.exs
config :opentelemetry,
  span_processor: :batch,
  traces_exporter: :otlp

config :opentelemetry_exporter,
  otlp_protocol: :http_protobuf,
  otlp_endpoint: "http://jaeger:4318",
  otlp_headers: [{"content-type", "application/x-protobuf"}]
```

### トレースの実装

```elixir
# 自動計装（Phoenix、Ecto）
# apps/*/lib/*/application.ex
OpentelemetryPhoenix.setup()
OpentelemetryEcto.setup([:my_app, :repo])

# 手動計装
require OpenTelemetry.Tracer

def process_order(order_params) do
  OpenTelemetry.Tracer.with_span "process_order" do
    # スパン属性の追加
    OpenTelemetry.Tracer.set_attributes([
      {"order.id", order_id},
      {"order.total", order_total}
    ])

    # 処理ロジック
    result = do_process(order_params)

    # イベントの記録
    OpenTelemetry.Tracer.add_event("order_processed", [
      {"items_count", length(order_params.items)}
    ])

    result
  end
end
```

### トレースの確認

1. Jaeger UI (http://localhost:16686) にアクセス
2. サービスを選択（例：`client-service`）
3. トレースを検索してリクエストフローを確認

## ログ管理

### ログレベルの設定

```elixir
# config/runtime.exs
config :logger, :console,
  level: System.get_env("LOG_LEVEL", "info") |> String.to_atom(),
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :trace_id, :span_id, :user_id]
```

### 構造化ログ

```elixir
# ログにメタデータを追加
Logger.info("Order created",
  order_id: order.id,
  user_id: user.id,
  total: order.total
)

# JSON フォーマットでログ出力
config :logger, :console,
  format: {LoggerJSON.Formatters.Basic, :format},
  metadata: :all
```

### ログの集約

Docker Compose でのログ確認：

```bash
# すべてのサービスのログ
docker-compose logs -f

# 特定のサービスのログ
docker-compose logs -f command-service

# エラーログのみ
docker-compose logs -f | grep ERROR

# 構造化ログの検索（jq を使用）
docker-compose logs -f --no-color | jq 'select(.level == "error")'
```

## リアルタイムモニタリング

### PubSubBroadcaster

PubSubBroadcaster は、システム全体のメッセージフローをリアルタイムで監視する機能を提供します。

#### 機能

- メッセージの一時キャッシュ（最大 1000 件）
- トピック別の統計収集
- GraphQL サブスクリプションへの配信
- メッセージレートの計測

#### トピック

- `events` - ドメインイベント
- `commands` - コマンドメッセージ
- `queries` - クエリメッセージ
- `sagas` - Saga 関連メッセージ

### GraphQL サブスクリプション

リアルタイムデータを取得するためのサブスクリプション：

```graphql
subscription {
  pubsubStream(topic: "events") {
    id
    topic
    payload
    timestamp
    source
  }
}
```

### Frontend モニタリングコンポーネント

#### MetricsDashboard

システムメトリクスをリアルタイムで表示：

- コマンド/クエリ実行数
- イベント出力率
- Saga の状態
- エラー率
- 平均実行時間

#### EventStream

イベントのリアルタイムストリーム表示：

- イベントタイプ別のフィルタリング
- イベントデータの詳細表示
- タイムスタンプとソース情報

#### FlowVisualization

システムフローの可視化：

- サービス間のメッセージフロー
- ノードの健全性状態
- リアルタイムのトラフィック表示

### WebSocket 監視

```elixir
# WebSocket 接続数のメトリクス
counter("websocket.connections.count", tags: [:status]),
summary("websocket.connection.duration", unit: {:native, :second}),
counter("websocket.messages.count", tags: [:direction, :type])
```

## ダッシュボード

### Grafana ダッシュボード

#### 1. システム概要ダッシュボード

主要メトリクス：

- リクエストレート（req/s）
- レスポンスタイム（p50, p95, p99）
- エラー率
- アクティブな接続数

#### 2. ビジネスメトリクスダッシュボード

- コマンド処理数（タイプ別）
- イベント生成率
- Saga の成功/失敗率
- 注文処理のファネル分析

#### 3. インフラストラクチャダッシュボード

- CPU 使用率
- メモリ使用量
- ディスク I/O
- ネットワークトラフィック

### ダッシュボードのインポート

```bash
# カスタムダッシュボードのインポート
curl -X POST http://localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <API_KEY>" \
  -d @dashboards/cqrs-overview.json
```

### Phoenix LiveDashboard

アプリケーション固有のメトリクス：

```elixir
# router.ex
live_dashboard "/dashboard",
  metrics: MyApp.Telemetry,
  ecto_repos: [MyApp.Repo],
  additional_pages: [
    live_dashboard_custom_page: MyApp.CustomPage
  ]
```

## アラート設定

### Prometheus アラートルール

```yaml
# prometheus/alerts.yml
groups:
  - name: application_alerts
    rules:
      - alert: HighErrorRate
        expr: rate(phoenix_request_errors_total[5m]) > 0.05
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High error rate detected"
          description: "Error rate is above 5% for 5 minutes"

      - alert: SlowResponseTime
        expr: histogram_quantile(0.95, phoenix_request_duration_seconds_bucket) > 1
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Slow response times"
          description: "95th percentile response time is above 1 second"

      - alert: SagaFailureRate
        expr: rate(saga_completed_count{status="failed"}[10m]) > 0.1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High Saga failure rate"
          description: "More than 10% of Sagas are failing"
```

### Grafana アラート

Grafana UI でのアラート設定：

1. ダッシュボードパネルを編集
2. Alert タブを選択
3. 条件を設定（例：`avg() > 100`）
4. 通知チャネルを設定（Email、Slack など）

## パフォーマンス分析

### ボトルネックの特定

#### 1. スロークエリの分析

```sql
-- PostgreSQL slow query log
ALTER SYSTEM SET log_min_duration_statement = 100; -- 100ms 以上のクエリをログ
SELECT pg_reload_conf();

-- 実行中のクエリを確認
SELECT pid, now() - pg_stat_activity.query_start AS duration, query
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes';
```

#### 2. Elixir プロセスの分析

```elixir
# IEx で実行
:observer.start()

# または recon を使用
:recon.proc_count(:memory, 10) # メモリ使用量 TOP 10
:recon.proc_count(:message_queue_len, 10) # メッセージキュー長 TOP 10
```

#### 3. トレースベースの分析

Jaeger でのレイテンシ分析：

1. サービスマップでボトルネックを視覚的に確認
2. トレース比較機能で正常時と異常時を比較
3. 依存関係グラフでサービス間の遅延を特定

### パフォーマンスチューニング

#### データベース最適化

```elixir
# コネクションプールの調整
config :my_app, MyApp.Repo,
  pool_size: 20,
  queue_target: 50,
  queue_interval: 1000

# プリペアドステートメントのキャッシュ
config :my_app, MyApp.Repo,
  prepare: :unnamed,
  statement_cache_size: 100
```

#### アプリケーション最適化

```elixir
# GenServer のタイムアウト調整
@timeout 30_000

# プロセスプールの使用
:poolboy.transaction(:worker_pool, fn worker ->
  GenServer.call(worker, {:process, data})
end)
```

## ベストプラクティス

### 1. メトリクスの命名規則

```
<namespace>.<component>.<action>.<unit>
例: order_service.command.process.duration
```

### 2. タグの活用

```elixir
# 高カーディナリティを避ける
# ❌ user_id をタグに使用
# ✅ user_type や country をタグに使用
```

### 3. SLO（Service Level Objectives）の設定

```yaml
# 99.9% の可用性
availability_slo: error_rate < 0.001

# 95% のリクエストが 200ms 以内
latency_slo: p95_latency < 200ms
```

### 4. ダッシュボードの構成

- RED メソッド（Rate、Errors、Duration）
- USE メソッド（Utilization、Saturation、Errors）
- ビジネス KPI の可視化

## トラブルシューティング

### メトリクスが表示されない

1. Prometheus targets を確認: http://localhost:9090/targets
2. サービスのメトリクスエンドポイントを確認: http://localhost:4001/metrics
3. ファイアウォール/ネットワーク設定を確認

### トレースが表示されない

1. OpenTelemetry の設定を確認
2. Jaeger エージェントの接続を確認
3. サンプリングレートを確認（開発環境では 100%）

### 高いメモリ使用量

1. `:observer.start()` で詳細を確認
2. メモリリークの可能性を調査
3. プロセスの再起動戦略を確認

## その他のリソース

- [Prometheus ドキュメント](https://prometheus.io/docs/)
- [Grafana ドキュメント](https://grafana.com/docs/)
- [Jaeger ドキュメント](https://www.jaegertracing.io/docs/)
- [OpenTelemetry Elixir](https://github.com/open-telemetry/opentelemetry-erlang)

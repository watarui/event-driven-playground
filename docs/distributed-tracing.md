# 分散トレーシング実装ガイド

## 概要

このプロジェクトでは OpenTelemetry を使用した分散トレーシングを実装しています。すべてのサービス間通信、コマンド実行、イベント処理、Saga 実行などが自動的にトレースされます。

## アーキテクチャ

### コンポーネント

1. **Tracing Config** (`Shared.Telemetry.Tracing.Config`)
   - OpenTelemetry の詳細設定
   - サンプリング戦略
   - エクスポーター設定

2. **Propagator** (`Shared.Telemetry.Tracing.Propagator`)
   - W3C Trace Context 形式のサポート
   - B3 形式のサポート（Zipkin 互換）
   - Baggage の伝播

3. **Span Builder** (`Shared.Telemetry.Tracing.SpanBuilder`)
   - 各種操作用のスパン構築
   - 標準化された属性設定

4. **Message Propagator** (`Shared.Telemetry.Tracing.MessagePropagator`)
   - メッセージングシステムでのトレース伝播
   - コマンド、クエリ、イベント、Saga のラッピング

5. **HTTP Plug** (`Shared.Telemetry.Tracing.Plug`)
   - Phoenix アプリケーションでの自動トレーシング
   - リクエスト/レスポンスの属性記録

## 設定

### 環境変数

```bash
# OTLP エンドポイント（デフォルト: http://localhost:4318）
export OPENTELEMETRY_OTLP_ENDPOINT="http://jaeger:4318"

# サンプリング比率（0.0-1.0、デフォルト: 1.0）
export OPENTELEMETRY_SAMPLING_RATIO="1.0"

# サービス名
export OPENTELEMETRY_SERVICE_NAME="elixir-cqrs"

# 環境
export OPENTELEMETRY_ENVIRONMENT="development"
```

### アプリケーション設定

```elixir
# config/config.exs
config :opentelemetry,
  otlp_endpoint: "http://localhost:4318",
  otlp_protocol: :http,  # :http または :grpc
  sampling_ratio: 1.0,
  sampling_strategy: :ratio,  # :always_on, :always_off, :ratio, :adaptive
  service_name: "elixir-cqrs",
  service_version: "1.0.0",
  environment: "development"
```

## 使用方法

### 1. Phoenix アプリケーションでの使用

```elixir
# router.ex
pipeline :api do
  plug :accepts, ["json"]
  plug Shared.Telemetry.Tracing.Plug  # トレーシングプラグを追加
end
```

### 2. コマンドバスでの使用

コマンドバスは自動的にトレーシングされています：

```elixir
# 自動的にトレースされる
CommandBus.dispatch(%CreateOrder{...})
```

### 3. イベントバスでの使用

イベントバスも自動的にトレーシングされています：

```elixir
# 自動的にトレースされる
EventBus.publish_event(%OrderCreated{...})
```

### 4. カスタムスパンの作成

```elixir
require OpenTelemetry.Tracer

OpenTelemetry.Tracer.with_span "custom_operation" do
  # 操作を実行
  result = do_something()
  
  # 属性を追加
  OpenTelemetry.Tracer.set_attributes(%{
    "operation.type" => "custom",
    "operation.result" => "success"
  })
  
  result
end
```

### 5. エラーの記録

```elixir
require OpenTelemetry.Tracer

OpenTelemetry.Tracer.with_span "risky_operation" do
  try do
    risky_operation()
  rescue
    e ->
      # エラーをスパンに記録
      OpenTelemetry.Tracer.record_exception(e)
      OpenTelemetry.Tracer.set_status(:error, Exception.message(e))
      reraise e, __STACKTRACE__
  end
end
```

## トレース情報の確認

### Jaeger UI

1. Jaeger UI にアクセス: http://localhost:16686
2. サービス一覧から対象サービスを選択
3. トレースを検索・表示

### トレース ID の確認

HTTP レスポンスヘッダーに含まれるトレース ID：

```
x-trace-id: 0af7651916cd43dd8448eb211c80319c
```

## サンプリング戦略

### 1. 常にサンプリング（開発環境）

```elixir
config :opentelemetry,
  sampling_strategy: :always_on
```

### 2. 比率ベースサンプリング（本番環境）

```elixir
config :opentelemetry,
  sampling_strategy: :ratio,
  sampling_ratio: 0.1  # 10% のトレースをサンプリング
```

### 3. アダプティブサンプリング

```elixir
config :opentelemetry,
  sampling_strategy: :adaptive
  # 1秒あたり最大100トレース
```

## パフォーマンスへの影響

- トレーシングのオーバーヘッドは最小限に抑えられています
- バッチ処理により、エクスポートの影響を軽減
- 本番環境では適切なサンプリング比率を設定してください

## トラブルシューティング

### トレースが表示されない

1. OTLP エンドポイントが正しいか確認
2. ネットワーク接続を確認
3. サンプリング設定を確認

### パフォーマンスの問題

1. サンプリング比率を下げる
2. バッチサイズを調整
3. エクスポートの頻度を調整

## 今後の拡張

1. **メトリクスの統合**
   - Prometheus エクスポーター追加
   - カスタムメトリクスの定義

2. **ログの統合**
   - トレース ID をログに含める
   - 構造化ログの実装

3. **アラートの設定**
   - レイテンシしきい値
   - エラー率の監視
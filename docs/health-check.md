# ヘルスチェックドキュメント

## 概要

システムは CQRS/Event Sourcing アプリケーションの全コンポーネントの状態を監視するための包括的なヘルスチェックエンドポイントを提供します。

## エンドポイント

### HTTP エンドポイント

#### `/health` - 詳細ヘルスチェック
全システムコンポーネントに関する包括的なヘルス情報を返します。

**レスポンス形式:**
```json
{
  "status": "healthy|degraded|unhealthy",
  "timestamp": "2024-01-13T10:30:45Z",
  "version": "0.1.0",
  "node": "node@hostname",
  "checks": [
    {
      "name": "database",
      "status": "healthy",
      "message": "Check passed",
      "details": {...},
      "duration_ms": 15
    }
  ]
}
```

**HTTP ステータスコード:**
- `200 OK` - システムは正常または一部機能低下
- `503 Service Unavailable` - システムは異常

#### `/health/live` - Liveness Probe
ロードバランサーや外部監視ツール用のシンプルなエンドポイント。

**レスポンス:**
- `200 OK` ボディ "OK" - サービスは生存中
- `503 Service Unavailable` - サービスは停止中

#### `/health/ready` - Readiness Probe
サービスがトラフィックを受け入れる準備ができているかを確認します。

**レスポンス:**
- `200 OK` ボディ "Ready" - サービスは準備完了
- `503 Service Unavailable` - サービスは準備未完了

#### `/health/{check_name}` - 特定のヘルスチェック
特定のヘルスチェックのみを実行します。

**利用可能なチェック名:**
- `database` - データベース接続
- `event_store` - イベントストア機能
- `memory` - メモリ使用量
- `services` - サービス状態
- `circuit_breakers` - サーキットブレーカー状態

### GraphQL エンドポイント

```graphql
query GetHealth {
  health {
    status
    timestamp
    version
    node
    checks {
      name
      status
      message
      details
      duration_ms
    }
  }
  
  memoryInfo {
    total_mb
    process_mb
    binary_mb
    ets_mb
    process_count
    port_count
  }
  
  serviceHealth(serviceName: "database") {
    status
    checks {
      name
      status
      message
    }
  }
}
```

## ヘルスチェックコンポーネント

### 1. データベースチェック
全データベースへの接続性を確認：
- Command Service DB
- Query Service DB
- Event Store DB

### 2. イベントストアチェック
イベントストア操作をテスト：
- 接続状態
- 書き込み機能
- 読み取り機能
- ストリーム数メトリクス

### 3. メモリチェック
Erlang VM のメモリ使用量を監視：
- 総メモリ
- プロセスメモリ
- バイナリメモリ
- ETS テーブルメモリ
- プロセス数とポート数

**閾値:**
- 警告: 総メモリ > 1GB
- クリティカル: 総メモリ > 2GB

### 4. サービスチェック
重要なサービスとオプショナルサービスを監視：

**重要なサービス:**
- Event Bus
- Command Bus
- Query Bus
- Saga Executor
- Service Registry

**オプショナルサービス:**
- Saga Monitor
- Saga Timeout Manager
- Circuit Breaker Supervisor
- Event Archiver

### 5. サーキットブレーカーチェック
サーキットブレーカーの状態を監視：
- Closed（正常動作）
- Open（障害検出）
- Half-open（復旧テスト中）

## ステータスレベル

### Healthy（正常）
全てのチェックが正常に完了。

### Degraded（一部機能低下）
- 1つ以上のオプショナルサービスが停止
- メモリ使用量が高いがクリティカルではない
- サーキットブレーカーが half-open 状態

### Unhealthy（異常）
- 重要なサービスが停止
- データベース接続失敗
- メモリ使用量がクリティカル
- サーキットブレーカーが open

## Cloud Run 統合

### ヘルスチェック設定
Cloud Run では、サービスの起動時と実行時のヘルスチェックが自動的に行われます：

- **起動プローブ**: TCP ポートチェック（自動）
- **ライブネスプローブ**: `/health/live` エンドポイント
- **レディネスプローブ**: `/health/ready` エンドポイント

### 外部監視ツール統合
Uptime Robot、Pingdom などの外部監視ツールでは `/health` エンドポイントを使用できます。

## 監視システム統合

### Prometheus メトリクス
ヘルスチェック結果は Prometheus メトリクスとしてもエクスポートされます：
- `health_check_status` - 全体的なヘルスステータス（0=healthy, 1=degraded, 2=unhealthy）
- `health_check_duration_seconds` - チェック実行時間
- `health_check_component_status` - 個別コンポーネントステータス

### Grafana ダッシュボード
以下を可視化する事前設定済みダッシュボードが利用可能：
- システム全体のヘルス
- 個別コンポーネントステータス
- メモリ使用量のトレンド
- サービス可用性

## トラブルシューティング

### よくある問題

1. **データベースチェック失敗**
   - データベースコンテナが実行中であることを確認
   - ネットワーク接続性を確認
   - 設定内の認証情報を確認

2. **メモリチェック警告**
   - メモリリークを監視
   - ガベージコレクションされていない大きなバイナリを確認
   - ETS テーブル使用量をレビュー

3. **サービスチェック失敗**
   - クラッシュレポートのアプリケーションログを確認
   - 必要な全サービスが起動していることを確認
   - 設定の問題を確認

### デバッグモード
詳細ログを有効化：
```elixir
config :logger, level: :debug
```

## ベストプラクティス

1. **定期的な監視**
   - ヘルスステータス変更のアラートを設定
   - 時系列でトレンドを監視
   - degraded 状態を迅速に調査

2. **負荷テスト**
   - 負荷テストにヘルスエンドポイントを含める
   - 負荷下でのヘルスチェックパフォーマンスを監視
   - チェックがシステムパフォーマンスに影響しないことを確認

3. **グレースフルデグラデーション**
   - degraded 状態を処理できるようシステムを設計
   - フォールバックメカニズムを実装
   - リカバリ手順を文書化
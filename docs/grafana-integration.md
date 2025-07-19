# Grafana 統合ガイド

## 概要

このプロジェクトでは、メトリクス可視化にハイブリッドアプローチを採用しています：
- **Grafana**: システムメトリクス、インフラ監視、履歴分析
- **カスタムダッシュボード (Next.js)**: リアルタイムビジネスメトリクスとイベントストリーム

## Grafana へのアクセス

1. インフラストラクチャが起動していることを確認：
   ```bash
   docker compose up -d
   ```

2. Grafana にアクセス: http://localhost:3000
   - デフォルトユーザー名: `admin`
   - デフォルトパスワード: `admin`

## 事前設定済みダッシュボード

### 1. システム概要ダッシュボード
- **場所**: Dashboards → Elixir CQRS System Overview
- **メトリクス**:
  - HTTP リクエスト率とエラー率
  - コマンド実行メトリクス
  - Saga 実行時間と期間
  - システムリソース（メモリ、プロセス）

### 2. ビジネスメトリクスダッシュボード
- **場所**: Dashboards → Business Metrics Dashboard
- **メトリクス**:
  - 注文フロー（作成、完了、キャンセル）
  - 支払い成功率
  - 在庫レベルと予約状況
  - 収益メトリクス

## カスタムメトリクス

アプリケーションは Prometheus 形式でカスタムメトリクスをエクスポートします：
- Client Service: http://localhost:4000/metrics

### 利用可能なメトリクスタイプ

#### システムメトリクス
- `http_requests_total`: メソッド、ステータス、パス別の HTTP リクエスト数
- `http_request_duration_seconds`: リクエストレイテンシのヒストグラム
- `erlang_vm_memory_bytes`: タイプ別の VM メモリ使用量
- `erlang_vm_process_count`: Erlang プロセス数

#### CQRS メトリクス
- `commands_total`: タイプとステータス別のコマンド実行数
- `command_duration_seconds`: コマンド実行時間のヒストグラム
- `events_published_total`: タイプ別の発行イベント数
- `saga_duration_seconds`: Saga 実行時間

#### ビジネスメトリクス
- `business_orders_*`: 注文ライフサイクルメトリクス
- `business_payments_*`: 支払い処理メトリクス
- `business_stock_*`: 在庫管理メトリクス

## カスタムダッシュボードの追加

1. Grafana UI で新しいダッシュボードを作成
2. ダッシュボードの JSON をエクスポート
3. `grafana/provisioning/dashboards/` に保存
4. Grafana コンテナを再起動

## アラート設定

Grafana でアラートを設定するには：

1. Alerting → Alert rules に移動
2. メトリクス閾値に基づいてルールを作成
3. 通知チャンネルを設定（メール、Slack など）

## ベストプラクティス

### Grafana を使用する場合
- インフラストラクチャ監視
- 履歴トレンド分析
- メトリクス閾値でのアラート
- キャパシティプランニング

### カスタムダッシュボードを使用する場合
- リアルタイムイベントストリーム
- ビジネス固有の可視化
- インタラクティブなデータ探索
- GraphQL サブスクリプションベースの更新

## トラブルシューティング

### メトリクスが表示されない場合
1. Prometheus ターゲットを確認: http://localhost:9090/targets
2. メトリクスエンドポイントを確認: http://localhost:4000/metrics
3. コンテナログを確認: `docker compose logs prometheus grafana`

### ダッシュボードが見つからない場合
1. `grafana/provisioning/` にプロビジョニングファイルが存在することを確認
2. プロビジョニングエラーについて Grafana ログを確認
3. 必要に応じて手動でダッシュボード JSON をインポート

## 参考資料
- [Grafana ドキュメント](https://grafana.com/docs/)
- [Prometheus クエリ言語](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [カスタムメトリクスドキュメント](./MONITORING.md)
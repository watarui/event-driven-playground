# システムアーキテクチャ

## 概要

このシステムは、CQRS (Command Query Responsibility Segregation)、Event Sourcing、SAGA パターンを実装したマイクロサービスアーキテクチャです。Phoenix PubSub を使用してサービス間の非同期通信を実現しています。

## システム構成図

```
┌─────────────────┐
│   Client App    │
│   (Browser)     │
└────────┬────────┘
         │ GraphQL (HTTP/WebSocket)
         ▼
┌─────────────────┐     Phoenix PubSub     ┌─────────────────┐
│ Client Service  │ ◄──────────────────────► │ Command Service │
│   (Port 4000)   │                         │                 │
└─────────────────┘                         └────────┬────────┘
         │                                            │
         │              Phoenix PubSub                │ Events
         │         ┌──────────────────────┐           ▼
         └─────────► │  Query Service    │ ◄─── Event Store
                    │                    │      (PostgreSQL)
                    └────────────────────┘
```

## マイクロサービス詳細

### 1. Shared (共通ライブラリ)

共通で使用されるコンポーネントを提供：

- **値オブジェクト**

  - `Money` - 日本円の金額を表現
  - `EntityId` - UUID ベースの識別子
  - `ProductName` - 商品名（1-100 文字）
  - `CategoryName` - カテゴリ名（1-50 文字）

- **ドメインイベント**

  - カテゴリイベント（作成、更新、削除）
  - 商品イベント（作成、更新、価格変更、削除）
  - 注文イベント（作成、確認、支払い処理、キャンセル）

- **インフラストラクチャ**
  - `EventStore` - イベントの永続化
  - `EventBus` - Phoenix PubSub を使用したイベント配信
  - `SagaExecutor` - SAGA の実行管理
  - `CircuitBreaker` - 障害時の回路遮断
  - `HealthChecker` - サービスの健全性監視

### 2. Command Service

書き込み操作を担当：

- **アグリゲート**

  - `CategoryAggregate` - カテゴリの状態とビジネスロジック
  - `ProductAggregate` - 商品の状態とビジネスロジック
  - `OrderAggregate` - 注文の状態とビジネスロジック

- **コマンドハンドラ**

  - カテゴリ、商品、注文の作成・更新・削除を処理
  - イベントストアへの永続化
  - イベントバスへの発行

- **SAGA**
  - `OrderSaga` - 注文処理の分散トランザクション管理

### 3. Query Service

読み取り操作を担当：

- **プロジェクション**

  - イベントからリードモデルを構築
  - カテゴリ、商品、注文の集計情報を管理

- **リポジトリ**

  - 最適化されたクエリ用データストア
  - キャッシュ層（ETS）を使用した高速化

- **クエリハンドラ**
  - Phoenix PubSub 経由でクエリを受信
  - リードモデルから効率的にデータを取得

### 4. Client Service

クライアント向け API を提供：

- **GraphQL API**

  - Absinthe を使用した GraphQL 実装
  - Dataloader による N+1 問題の解決
  - WebSocket によるリアルタイムサブスクリプション
  - PubSubBroadcaster によるメッセージキャッシングと配信

- **通信層**
  - Phoenix PubSub を使用した非同期通信
  - タイムアウト処理とエラーハンドリング
  - AbsintheSocket による WebSocket 接続管理
  - リアルタイムモニタリングとメトリクス収集

## データフロー

### コマンド（書き込み）フロー

1. クライアントが GraphQL mutation を送信
2. Client Service がコマンドを Phoenix PubSub 経由で Command Service に送信
3. Command Service がコマンドを処理し、アグリゲートを更新
4. イベントがイベントストアに保存される
5. イベントが Phoenix PubSub 経由で配信される
6. Query Service がイベントを受信し、プロジェクションを更新
7. PubSubBroadcaster がイベントを WebSocket 経由でクライアントに配信

### クエリ（読み取り）フロー

1. クライアントが GraphQL query を送信
2. Client Service がクエリを Phoenix PubSub 経由で Query Service に送信
3. Query Service がリードモデルからデータを取得
4. 結果が Client Service に返される
5. GraphQL レスポンスとしてクライアントに返される

## 技術的な選択

### Phoenix PubSub を選択した理由

- Elixir/Phoenix エコシステムとの親和性
- 低レイテンシの通信
- 組み込みのクラスタリングサポート
- シンプルな実装

### PostgreSQL ベースのイベントストア

- トランザクションの保証
- 既存の運用知識の活用
- スナップショット機能のサポート
- 高い信頼性

### ETS によるキャッシュ

- インメモリの高速アクセス
- プロセス間での共有
- TTL とサイズ制限のサポート
- Erlang VM のネイティブ機能

## リアルタイム機能

### WebSocket サブスクリプション

- **イベントストリーム** - すべてのドメインイベントのリアルタイム配信
- **PubSub ストリーム** - トピック別メッセージのリアルタイム配信
- **Saga 更新** - Saga の状態変更通知
- **ダッシュボード統計** - システムメトリクスのリアルタイム更新
- **メトリクスストリーム** - パフォーマンスメトリクスのリアルタイム配信

### PubSubBroadcaster

- メッセージの一時キャッシュ（最大 1000 件）
- トピック別の統計収集
- GraphQL サブスクリプションへの効率的な配信
- メッセージ履歴の提供

## モニタリングとオブザーバビリティ

### システムトポロジー

- ノード間の接続状態の可視化
- サービスの健全性監視
- リアルタイムのメッセージフロー表示

### メトリクス収集

- コマンド/クエリの実行時間
- イベント処理のスループット
- Saga の実行状態
- システムリソースの使用状況

## スケーラビリティ

- 各サービスは独立してスケール可能
- Phoenix PubSub のクラスタリング対応
- リードモデルの複製による読み取りスケール
- WebSocket 接続の水平分散
- PubSubBroadcaster によるメッセージの効率的な配信

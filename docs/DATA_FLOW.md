# CQRS/ES システムのデータフロー

このドキュメントでは、CQRS/ES システムにおけるデータの流れと、各データベースの役割を説明します。

## 📊 システム概要

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   Client    │────▶│ GraphQL API  │────▶│  Command    │
│  (Browser)  │◄────│  (Gateway)   │     │  Service    │
└─────────────┘ WS  └──────┬───────┘     └─────────────┘
                            │                     │
                            │                     ▼
                            │              ┌─────────────┐
                            │              │ Event Store │
                            │              └─────┬──────┘
                            │                     │
                            │                     ▼
                            │              ┌─────────────┐     ┌─────────────────┐
                            └─────────────▶│   Query     │────▶│PubSubBroadcaster│
                                          │  Service    │     └─────────────────┘
                                          └─────────────┘
```

## 🗄️ データベースの構成

### 1. Event Store DB (ポート: 5432)

**役割**: すべてのビジネスイベントを不変のログとして記録

| テーブル  | 用途                           | 主なカラム                                                                           |
| --------- | ------------------------------ | ------------------------------------------------------------------------------------ |
| events    | イベントログ                   | aggregate_id, aggregate_type, event_type, event_data, event_version, global_sequence |
| snapshots | アグリゲートのスナップショット | aggregate_id, version, data                                                          |
| sagas     | SAGA の状態管理                | saga_id, saga_type, state, status, current_step                                      |

### 2. Command DB (ポート: 5433)

**役割**: コマンド処理時の現在の状態を保持（書き込みモデル）

| テーブル   | 用途               | 主なカラム                                                   |
| ---------- | ------------------ | ------------------------------------------------------------ |
| categories | カテゴリの現在状態 | id, name, description, parent_id, active, version            |
| products   | 商品の現在状態     | id, name, category_id, price_amount, stock_quantity, version |

**注意**: orders テーブルは存在しません。注文は Event Store のみで管理されます。

### 3. Query DB (ポート: 5434)

**役割**: 読み取り専用のプロジェクション（読み取りモデル）

| テーブル   | 用途           | 主なカラム                                      |
| ---------- | -------------- | ----------------------------------------------- |
| categories | カテゴリ表示用 | id, name, description                           |
| products   | 商品表示用     | id, name, category_id, price, stock_quantity    |
| orders     | 注文表示用     | id, user_id, status, total_amount, items (JSON) |

## 🔄 データフローの詳細

### 1. コマンドの処理フロー

```
1. Client → GraphQL Mutation → Command Service
2. Command Service:
   a. コマンドの検証
   b. アグリゲートの復元（Event Store から）
   c. ビジネスロジックの実行
   d. イベントの生成
3. イベントを Event Store に保存
4. イベントを EventBus に発行
5. 必要に応じて Command DB を更新（カテゴリ、商品のみ）
```

### 2. クエリの処理フロー

```
1. Client → GraphQL Query → Query Service
2. Query Service:
   a. Query DB から読み取り専用データを取得
   b. 必要に応じてキャッシュを使用
3. レスポンスを返却
```

### 3. イベントの伝播フロー

```
1. Event Store にイベントが保存される
2. EventBus がイベントを発行
3. ProjectionManager が購読してイベントを受信
4. 該当するプロジェクションハンドラーを実行
5. Query DB のプロジェクションを更新
6. PubSubBroadcaster がイベントをキャッシュし、WebSocket 経由で配信
```

### 4. リアルタイムデータフロー

```
1. PubSubBroadcaster が Phoenix.PubSub からメッセージを受信
2. メッセージをキャッシュ（最大 1000 件）
3. トピック別に統計を更新
4. GraphQL サブスクリプション経由でクライアントに配信
5. クライアントが WebSocket 経由でリアルタイム更新を受信
```

#### 監視対象トピック

- `events` - ドメインイベント
- `commands` - コマンドメッセージ
- `queries` - クエリメッセージ
- `sagas` - Saga 関連メッセージ

## 📈 データの一貫性

### イベントソーシングの利点

- **監査証跡**: すべての変更がイベントとして記録される
- **時点復元**: 任意の時点の状態を再構築可能
- **イベント再生**: プロジェクションの再構築が可能

### 結果整合性

- Command 実行直後は Query DB に反映されない可能性がある
- 通常、数ミリ秒〜数秒で同期される
- プロジェクションの再構築により整合性を保証

## 🔍 監視とデバッグ

### GraphQL クエリによる監視

```graphql
# イベントストアの統計情報
{
  eventStoreStats {
    totalEvents
    eventsByType {
      eventType
      count
    }
    latestSequence
  }
}

# システム全体の統計
{
  systemStatistics {
    eventStore {
      totalRecords
    }
    commandDb {
      totalRecords
    }
    queryDb {
      categories
      products
      orders
    }
    sagas {
      active
      completed
      failed
    }
  }
}

# プロジェクションの状態
{
  projectionStatus {
    name
    status
    processedCount
    lastError
  }
}
```

### プロジェクションの再構築

Event Store と Query DB の同期が取れていない場合は、[開発ガイド](DEVELOPMENT.md#プロジェクションの管理) を参照してプロジェクションを再構築してください。

```bash
# プロジェクションを再構築
mix run scripts/seed_demo_data.exs
```

## 🚨 トラブルシューティング

### Query DB にデータが反映されない場合

1. **ProjectionManager の状態を確認**

   ```graphql
   {
     projectionStatus {
       name
       status
       lastError
     }
   }
   ```

2. **EventBus の接続を確認**

   - ノード間の接続状態を確認
   - EventBus のプロセスが生きているか確認

3. **手動でプロジェクションを再構築**
   ```bash
   mix run scripts/seed_demo_data.exs
   ```

詳細なトラブルシューティング手順については [TROUBLESHOOTING.md](TROUBLESHOOTING.md#プロジェクション) を参照してください。

## 🌐 リアルタイム監視

### GraphQL サブスクリプション

```graphql
# イベントストリーム
subscription {
  eventStream {
    id
    aggregateId
    eventType
    eventData
    occurredAt
  }
}

# PubSub メッセージストリーム
subscription {
  pubsubStream(topic: "events") {
    id
    topic
    payload
    timestamp
    source
  }
}

# ダッシュボード統計
subscription {
  dashboardStatsStream {
    commandsExecuted
    queriesExecuted
    eventsPublished
    sagasActive
    errors
  }
}
```

### WebSocket 接続

- **エンドポイント**: `ws://localhost:4000/socket`
- **プロトコル**: GraphQL over WebSocket
- **ライブラリ**: Absinthe による GraphQL サブスクリプション

## 📝 まとめ

- **永続化データ**: Event Store（イベント）、Command DB（現在状態）、Query DB（読み取りモデル）
- **ストリームデータ**: EventBus を通じたリアルタイムイベント配信
- **データの流れ**: Command → Event Store → EventBus → Query Service → Query DB
- **リアルタイム配信**: PubSubBroadcaster → WebSocket → Client
- **整合性**: 結果整合性モデル（通常は数ミリ秒で同期）

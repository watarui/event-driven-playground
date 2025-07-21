# アーキテクチャ

## 概要

Event Driven Playground は、CQRS (Command Query Responsibility Segregation) と Event Sourcing パターンを実装したマイクロサービスアーキテクチャです。

## システム構成

```mermaid
graph TB
    subgraph "Frontend"
        UI[Next.js App]
    end
    
    subgraph "Backend Services"
        GQL[Client Service<br/>GraphQL API]
        CMD[Command Service]
        QRY[Query Service]
    end
    
    subgraph "Infrastructure"
        PS[Cloud Pub/Sub]
        FS[Firestore]
    end
    
    UI --> |GraphQL| GQL
    GQL --> |Commands| CMD
    GQL --> |Queries| QRY
    CMD --> |Events| PS
    PS --> |Events| QRY
    CMD --> |Event Store| FS
    QRY --> |Read Model| FS
```

## 主要コンポーネント

### 1. Client Service (GraphQL API)

- **役割**: フロントエンドとバックエンドサービス間のゲートウェイ
- **技術**: Phoenix Framework + Absinthe
- **機能**:
  - GraphQL スキーマの定義と実行
  - 認証・認可（Firebase Authentication）
  - コマンドとクエリのルーティング

### 2. Command Service

- **役割**: コマンド（書き込み操作）の処理
- **責務**:
  - ビジネスロジックの実行
  - イベントの生成と永続化
  - ドメインの整合性保証
- **パターン**: アグリゲートパターンを使用

### 3. Query Service

- **役割**: クエリ（読み取り操作）の処理
- **責務**:
  - Read Model の構築と管理
  - 最適化されたクエリの実行
  - イベントからの投影（Projection）

## CQRS と Event Sourcing

### CQRS の実装

```elixir
# コマンド側（Command Service）
defmodule CommandService.Products.CreateProduct do
  def execute(params) do
    # ビジネスロジックの実行
    # イベントの生成
    # Event Store への保存
  end
end

# クエリ側（Query Service）
defmodule QueryService.Products.GetProduct do
  def execute(product_id) do
    # Read Model から最適化されたデータを取得
  end
end
```

### Event Sourcing の実装

すべての状態変更はイベントとして記録されます：

```elixir
# イベントの例
%ProductCreated{
  aggregate_id: "product-123",
  name: "商品名",
  price: 1000,
  category_id: "category-456",
  timestamp: ~U[2024-01-01 00:00:00Z]
}
```

## データフロー

### 1. コマンドフロー（書き込み）

1. フロントエンドが GraphQL Mutation を送信
2. Client Service がコマンドを Command Service にルーティング
3. Command Service がビジネスロジックを実行
4. イベントを生成し、Event Store（Firestore）に保存
5. イベントを Pub/Sub に発行
6. 成功/失敗をフロントエンドに返す

### 2. クエリフロー（読み取り）

1. フロントエンドが GraphQL Query を送信
2. Client Service がクエリを Query Service にルーティング
3. Query Service が Read Model から最適化されたデータを取得
4. 結果をフロントエンドに返す

### 3. イベント処理フロー

1. Command Service がイベントを Pub/Sub に発行
2. Query Service がイベントをサブスクライブ
3. イベントハンドラーが Read Model を更新
4. 最新の状態がクエリで利用可能になる

## Firestore の使用

### コレクション構造

```
firestore/
├── events/                    # Event Store
│   └── {aggregate_id}/
│       └── {event_id}        # 個別のイベント
├── command_service/           # Command側の状態
│   ├── categories/
│   ├── products/
│   └── orders/
└── query_service/            # Read Model
    ├── categories/
    ├── products/
    └── orders/
```

### Event Store の設計

- 各アグリゲートのイベントは独立したコレクションに保存
- イベントは append-only（追加のみ）
- イベントの順序は timestamp で管理

## スケーラビリティ

### 水平スケーリング

- 各サービスは独立してスケール可能
- Cloud Run の自動スケーリング機能を活用
- Read Model の複製による読み取り性能の向上

### 非同期処理

- Pub/Sub による疎結合
- イベント駆動による最終的整合性
- バックプレッシャー制御

## セキュリティ

### 認証・認可

- Firebase Authentication による認証
- JWT トークンの検証
- ロールベースのアクセス制御（RBAC）

### データ保護

- HTTPS による通信の暗号化
- Firestore のセキュリティルール
- Secret Manager による機密情報管理

## 監視とロギング

### メトリクス

- Cloud Monitoring によるシステムメトリクス
- カスタムメトリクス（処理時間、エラー率など）
- アラート設定

### トレーシング

- OpenTelemetry による分散トレーシング
- リクエストの追跡とボトルネックの特定

### ロギング

- 構造化ログ（JSON形式）
- Cloud Logging への集約
- エラーログの自動アラート
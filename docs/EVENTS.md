# イベントリファレンス

## 概要

このドキュメントでは、システムで使用されるすべてのドメインイベントについて説明します。イベントは Phoenix PubSub を通じて配信され、イベントストアに永続化されます。

## イベントの基本構造

すべてのイベントは以下の共通インターフェースを実装しています：

```elixir
@callback event_type() :: String.t()
@callback new(params :: map()) :: {:ok, t()} | {:error, String.t()}
```

## カテゴリイベント

### CategoryCreated

カテゴリが作成されたときに発行されます。

**イベントタイプ**: `category.created`

**フィールド**:

- `id` (EntityId) - カテゴリ ID
- `name` (CategoryName) - カテゴリ名
- `description` (String) - 説明（オプション）
- `parent_id` (EntityId) - 親カテゴリ ID（オプション）
- `created_at` (DateTime) - 作成日時

**例**:

```elixir
%CategoryCreated{
  id: %EntityId{value: "123e4567-e89b-12d3-a456-426614174000"},
  name: %CategoryName{value: "家電"},
  description: "家電製品のカテゴリ",
  parent_id: nil,
  created_at: ~U[2024-01-01 00:00:00Z]
}
```

### CategoryUpdated

カテゴリが更新されたときに発行されます。

**イベントタイプ**: `category.updated`

**フィールド**:

- `id` (EntityId) - カテゴリ ID
- `name` (CategoryName) - 新しいカテゴリ名（オプション）
- `description` (String) - 新しい説明（オプション）
- `parent_id` (EntityId) - 新しい親カテゴリ ID（オプション）
- `updated_at` (DateTime) - 更新日時

### CategoryDeleted

カテゴリが削除されたときに発行されます。

**イベントタイプ**: `category.deleted`

**フィールド**:

- `id` (EntityId) - カテゴリ ID
- `deleted_at` (DateTime) - 削除日時

## 商品イベント

### ProductCreated

商品が作成されたときに発行されます。

**イベントタイプ**: `product.created`

**フィールド**:

- `id` (EntityId) - 商品 ID
- `name` (ProductName) - 商品名
- `description` (String) - 説明（オプション）
- `price` (Money) - 価格
- `category_id` (EntityId) - カテゴリ ID
- `stock_quantity` (Integer) - 在庫数（オプション）
- `created_at` (DateTime) - 作成日時

**例**:

```elixir
%ProductCreated{
  id: %EntityId{value: "456e7890-e89b-12d3-a456-426614174000"},
  name: %ProductName{value: "ノートパソコン"},
  description: "高性能ノートPC",
  price: %Money{amount: Decimal.new("150000"), currency: "JPY"},
  category_id: %EntityId{value: "123e4567-e89b-12d3-a456-426614174000"},
  stock_quantity: 10,
  created_at: ~U[2024-01-01 00:00:00Z]
}
```

### ProductUpdated

商品が更新されたときに発行されます。

**イベントタイプ**: `product.updated`

**フィールド**:

- `id` (EntityId) - 商品 ID
- `name` (ProductName) - 新しい商品名（オプション）
- `description` (String) - 新しい説明（オプション）
- `category_id` (EntityId) - 新しいカテゴリ ID（オプション）
- `updated_at` (DateTime) - 更新日時

### ProductPriceChanged

商品価格が変更されたときに発行されます。

**イベントタイプ**: `product.price_changed`

**フィールド**:

- `id` (EntityId) - 商品 ID
- `old_price` (Money) - 旧価格
- `new_price` (Money) - 新価格
- `changed_at` (DateTime) - 変更日時

### ProductDeleted

商品が削除されたときに発行されます。

**イベントタイプ**: `product.deleted`

**フィールド**:

- `id` (EntityId) - 商品 ID
- `deleted_at` (DateTime) - 削除日時

## 注文イベント

### OrderCreated

注文が作成されたときに発行されます。

**イベントタイプ**: `order.created`

**フィールド**:

- `id` (EntityId) - 注文 ID
- `user_id` (EntityId) - ユーザー ID
- `items` (List) - 注文アイテムのリスト
  - `product_id` (String) - 商品 ID
  - `product_name` (String) - 商品名
  - `quantity` (Integer) - 数量
  - `unit_price` (Decimal) - 単価
- `total_amount` (Money) - 合計金額
- `created_at` (DateTime) - 作成日時

**例**:

```elixir
%OrderCreated{
  id: %EntityId{value: "789e0123-e89b-12d3-a456-426614174000"},
  user_id: %EntityId{value: "user-123"},
  items: [
    %{
      product_id: "456e7890-e89b-12d3-a456-426614174000",
      product_name: "ノートパソコン",
      quantity: 2,
      unit_price: Decimal.new("150000")
    }
  ],
  total_amount: %Money{amount: Decimal.new("300000"), currency: "JPY"},
  created_at: ~U[2024-01-01 00:00:00Z]
}
```

### OrderConfirmed

注文が確認されたときに発行されます。

**イベントタイプ**: `order.confirmed`

**フィールド**:

- `id` (EntityId) - 注文 ID
- `confirmed_at` (DateTime) - 確認日時

### OrderPaymentProcessed

注文の支払いが処理されたときに発行されます。

**イベントタイプ**: `order.payment_processed`

**フィールド**:

- `order_id` (EntityId) - 注文 ID
- `payment_id` (String) - 支払い ID
- `amount` (Money) - 支払い金額
- `processed_at` (DateTime) - 処理日時

### OrderCancelled

注文がキャンセルされたときに発行されます。

**イベントタイプ**: `order.cancelled`

**フィールド**:

- `id` (EntityId) - 注文 ID
- `reason` (String) - キャンセル理由
- `cancelled_at` (DateTime) - キャンセル日時

### OrderItemReserved

注文アイテムの在庫が予約されたときに発行されます。

**イベントタイプ**: `order.item_reserved`

**フィールド**:

- `order_id` (EntityId) - 注文 ID
- `product_id` (String) - 商品 ID
- `quantity` (Integer) - 予約数量
- `reserved_at` (DateTime) - 予約日時

## イベントの購読

### Phoenix PubSub での購読

```elixir
# 特定のイベントタイプを購読
EventBus.subscribe("category.created")
EventBus.subscribe("product.*")  # ワイルドカード

# イベントの受信
def handle_info({:event, event}, state) do
  case event do
    %CategoryCreated{} -> handle_category_created(event)
    %ProductCreated{} -> handle_product_created(event)
    _ -> :ok
  end
  {:noreply, state}
end
```

### イベントストアからの取得

```elixir
# アグリゲートのすべてのイベントを取得
{:ok, events} = EventStore.get_events(aggregate_id)

# 特定のイベントタイプを取得
{:ok, events} = EventStore.get_events_by_type("category.created", limit: 100)
```

## イベントのバージョニング

将来的にイベントの構造を変更する必要がある場合：

1. 新しいバージョンのイベントを作成（例：`CategoryCreatedV2`）
2. 古いイベントとの互換性を保つアップキャスターを実装
3. 段階的に移行

## ベストプラクティス

1. **イベントは不変**: 一度発行されたイベントは変更しない
2. **必要最小限の情報**: イベントには必要な情報のみを含める
3. **ビジネス用語を使用**: 技術的な用語よりもビジネス用語を優先
4. **イベントの順序を保証**: アグリゲートごとにイベントの順序を保証

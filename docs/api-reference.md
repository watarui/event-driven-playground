# API リファレンス

## GraphQL エンドポイント

- **開発環境**: `http://localhost:4000/graphql`
- **本番環境**: `https://your-api-domain.com/graphql`

## 認証

Firebase Authentication を使用しています。すべてのリクエストに Authorization ヘッダーが必要です：

```
Authorization: Bearer <firebase-id-token>
```

## スキーマ

### カテゴリ (Category)

```graphql
type Category {
  id: ID!
  name: String!
  parentId: ID
  createdAt: DateTime!
  updatedAt: DateTime!
}
```

### 商品 (Product)

```graphql
type Product {
  id: ID!
  name: String!
  description: String
  price: Int!
  stock: Int!
  categoryId: ID!
  category: Category!
  createdAt: DateTime!
  updatedAt: DateTime!
}
```

### 注文 (Order)

```graphql
type Order {
  id: ID!
  customerId: ID!
  items: [OrderItem!]!
  totalAmount: Int!
  status: OrderStatus!
  createdAt: DateTime!
  updatedAt: DateTime!
}

type OrderItem {
  productId: ID!
  product: Product!
  quantity: Int!
  price: Int!
}

enum OrderStatus {
  PENDING
  CONFIRMED
  PAID
  CANCELLED
}
```

## クエリ

### カテゴリ取得

```graphql
# 全カテゴリを取得
query GetCategories {
  categories {
    id
    name
    parentId
  }
}

# 特定のカテゴリを取得
query GetCategory($id: ID!) {
  category(id: $id) {
    id
    name
    parentId
    products {
      id
      name
      price
    }
  }
}
```

### 商品取得

```graphql
# 全商品を取得
query GetProducts {
  products {
    id
    name
    price
    stock
    category {
      id
      name
    }
  }
}

# カテゴリで絞り込み
query GetProductsByCategory($categoryId: ID!) {
  products(categoryId: $categoryId) {
    id
    name
    price
    stock
  }
}

# 特定の商品を取得
query GetProduct($id: ID!) {
  product(id: $id) {
    id
    name
    description
    price
    stock
    category {
      id
      name
    }
  }
}
```

### 注文取得

```graphql
# ユーザーの注文一覧を取得
query GetMyOrders {
  myOrders {
    id
    totalAmount
    status
    createdAt
    items {
      product {
        name
      }
      quantity
      price
    }
  }
}

# 特定の注文を取得
query GetOrder($id: ID!) {
  order(id: $id) {
    id
    customerId
    totalAmount
    status
    items {
      productId
      product {
        name
      }
      quantity
      price
    }
  }
}
```

## ミューテーション

### カテゴリ操作

```graphql
# カテゴリ作成
mutation CreateCategory($input: CreateCategoryInput!) {
  createCategory(input: $input) {
    id
    name
    parentId
  }
}

input CreateCategoryInput {
  name: String!
  parentId: ID
}

# カテゴリ更新
mutation UpdateCategory($id: ID!, $input: UpdateCategoryInput!) {
  updateCategory(id: $id, input: $input) {
    id
    name
    parentId
  }
}

input UpdateCategoryInput {
  name: String
  parentId: ID
}

# カテゴリ削除
mutation DeleteCategory($id: ID!) {
  deleteCategory(id: $id) {
    success
    message
  }
}
```

### 商品操作

```graphql
# 商品作成
mutation CreateProduct($input: CreateProductInput!) {
  createProduct(input: $input) {
    id
    name
    price
    stock
  }
}

input CreateProductInput {
  name: String!
  description: String
  price: Int!
  stock: Int!
  categoryId: ID!
}

# 商品更新
mutation UpdateProduct($id: ID!, $input: UpdateProductInput!) {
  updateProduct(id: $id, input: $input) {
    id
    name
    price
    stock
  }
}

input UpdateProductInput {
  name: String
  description: String
  price: Int
  stock: Int
  categoryId: ID
}

# 在庫調整
mutation AdjustStock($productId: ID!, $quantity: Int!) {
  adjustStock(productId: $productId, quantity: $quantity) {
    id
    stock
  }
}
```

### 注文操作

```graphql
# 注文作成
mutation CreateOrder($input: CreateOrderInput!) {
  createOrder(input: $input) {
    id
    totalAmount
    status
  }
}

input CreateOrderInput {
  items: [OrderItemInput!]!
}

input OrderItemInput {
  productId: ID!
  quantity: Int!
}

# 注文確認
mutation ConfirmOrder($orderId: ID!) {
  confirmOrder(orderId: $orderId) {
    id
    status
  }
}

# 支払い処理
mutation ProcessPayment($orderId: ID!) {
  processPayment(orderId: $orderId) {
    id
    status
  }
}

# 注文キャンセル
mutation CancelOrder($orderId: ID!) {
  cancelOrder(orderId: $orderId) {
    id
    status
  }
}
```

## サブスクリプション

```graphql
# 商品の在庫変更を監視
subscription OnStockChanged($productId: ID!) {
  stockChanged(productId: $productId) {
    productId
    oldStock
    newStock
  }
}

# 注文ステータスの変更を監視
subscription OnOrderStatusChanged($orderId: ID!) {
  orderStatusChanged(orderId: $orderId) {
    orderId
    oldStatus
    newStatus
  }
}
```

## エラーハンドリング

エラーは以下の形式で返されます：

```json
{
  "errors": [
    {
      "message": "エラーメッセージ",
      "extensions": {
        "code": "ERROR_CODE",
        "details": {}
      }
    }
  ]
}
```

### エラーコード

- `UNAUTHENTICATED`: 認証が必要
- `FORBIDDEN`: アクセス権限なし
- `NOT_FOUND`: リソースが見つからない
- `INVALID_INPUT`: 入力値が不正
- `BUSINESS_RULE_VIOLATION`: ビジネスルール違反
- `INTERNAL_ERROR`: サーバーエラー

## レート制限

- 認証済みユーザー: 1000リクエスト/分
- 未認証ユーザー: 100リクエスト/分

## ページネーション

リスト系のクエリはページネーションをサポートしています：

```graphql
query GetProducts($limit: Int, $offset: Int) {
  products(limit: $limit, offset: $offset) {
    edges {
      node {
        id
        name
      }
    }
    pageInfo {
      hasNextPage
      totalCount
    }
  }
}
```
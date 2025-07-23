# 本番環境でのSAGAテスト手順

## 前提条件
- 管理者またはWriterロールでログイン済み
- GraphiQL（https://event-driven-playground.vercel.app/graphiql）を開いている

## テストシナリオ

### 1. 基本データの準備

1. **カテゴリを作成**
   ```graphql
   mutation {
     electronics: createCategory(input: { name: "電子機器" }) {
       id
       name
     }
     books: createCategory(input: { name: "書籍" }) {
       id
       name
     }
   }
   ```

2. **商品を作成**（カテゴリIDを上記の結果から取得して置き換え）
   ```graphql
   mutation {
     laptop: createProduct(input: {
       name: "ノートPC"
       price: 150000
       stock: 5
       categoryId: "YOUR_ELECTRONICS_CATEGORY_ID"
     }) {
       id
       name
       stock
     }
     book: createProduct(input: {
       name: "技術書"
       price: 3000
       stock: 20
       categoryId: "YOUR_BOOKS_CATEGORY_ID"
     }) {
       id
       name
       stock
     }
   }
   ```

### 2. SAGAの正常系テスト

**正常な注文を作成**（商品IDを上記の結果から取得）
```graphql
mutation {
  createOrder(input: {
    items: [
      { productId: "YOUR_LAPTOP_ID", quantity: 1 },
      { productId: "YOUR_BOOK_ID", quantity: 2 }
    ]
  }) {
    id
    status
    totalAmount
    items {
      product { name }
      quantity
      price
    }
  }
}
```

**期待される動作:**
1. 注文が作成される（status: "PENDING"）
2. 在庫が確保される
3. 決済が処理される
4. 配送が手配される
5. 注文が確定される（status: "CONFIRMED"）

### 3. SAGAの異常系テスト（補償トランザクション）

**在庫不足の注文**
```graphql
mutation {
  createOrder(input: {
    items: [
      { productId: "YOUR_LAPTOP_ID", quantity: 100 }
    ]
  }) {
    id
    status
  }
}
```

**期待される動作:**
1. 注文が作成される
2. 在庫確保が失敗する
3. SAGAが補償トランザクションを実行
4. 注文がキャンセルされる（status: "FAILED" または "CANCELLED"）

### 4. イベントの確認

**イベントストアの統計を確認**
```graphql
query {
  eventStore {
    statistics {
      eventCount
      eventTypes
      newestEvent
    }
  }
}
```

### 5. システム状態の確認

**全体のヘルスチェック**
```graphql
query {
  health {
    status
    checks {
      name
      status
      message
    }
  }
}
```

**注文履歴の確認**
```graphql
query {
  myOrders {
    id
    status
    totalAmount
    createdAt
    items {
      product { name }
      quantity
    }
  }
}
```

## トラブルシューティング

### エラーが発生した場合

1. **ブラウザのコンソールログを確認**
   - ネットワークエラー
   - 認証エラー

2. **Vercel Functionsのログを確認**
   - Vercelダッシュボード > Functions タブ
   - 各サービスのログを確認

3. **Cloud Runのログを確認**
   ```bash
   gcloud logging read "resource.type=cloud_run_revision" \
     --project=event-driven-playground-prod \
     --limit=50
   ```

### よくある問題

1. **認証エラー（401）**
   - ログアウトして再度ログイン
   - トークンをリフレッシュ（GraphiQLページのRefreshボタン）

2. **権限エラー（403）**
   - Writerまたは管理者ロールが必要
   - 管理者設定ボタンから権限を取得

3. **サービスエラー（500）**
   - 一時的な問題の可能性
   - 数秒待って再試行
# Vercel 本番環境変数設定

## 設定すべき環境変数一覧

### 1. API エンドポイント（Cloud Run デプロイ後に更新）

```
NEXT_PUBLIC_GRAPHQL_ENDPOINT=https://client-service-prod-XXXXX.asia-northeast1.run.app/graphql
NEXT_PUBLIC_WS_ENDPOINT=wss://client-service-prod-XXXXX.asia-northeast1.run.app/socket/websocket
```

**注意**: `XXXXX` の部分は実際の Cloud Run サービス URL に置き換えてください。

### 2. Firebase Configuration (Public)

```
NEXT_PUBLIC_FIREBASE_API_KEY=AIzaSyB2tcXCHffMcLReMtFl3PLTARRawlyQys4
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=elixir-cqrs-es.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=elixir-cqrs-es
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=elixir-cqrs-es.firebasestorage.app
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=581148615576
NEXT_PUBLIC_FIREBASE_APP_ID=1:581148615576:web:0af8c9eab9e6f652b741ed
```

### 3. Firebase Admin SDK (Secret - Sensitive として設定)

```
FIREBASE_PROJECT_ID=elixir-cqrs-es
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-fbsvc@elixir-cqrs-es.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIIEvwIBADANBgkqhkiG9w0BAQEFAASCBKkwggSlAgEAAoIBAQDNXaAxCQvdM4o1\ncDAmq0dX575Ik2R9DkwLOog7ah0GtWtXRSsU9QP8ceZbi1MJizfzT+FBTX5zA4hi\nDxpfzwfkeV4ZUhc5kvCJXLRMP+mWtGfPUXcI+iBt8Wdlv9zf1qX4W74v0AXCeIWn\nr0YjSFcGN9ovf4l4wHefEWqnA7UvzwhdD3eCabGQf0d1tykskbXyRgh1AOm8Hsjb\naT/CKwntS3iMOn6bP+NfOc4kksxjBorCl5KFjEKrzRxqfsOILQf4ofO9pkeH3uLE\nu2tZHap/aUUq1jiJqLTi6UficWvNd+DkLhMdtcES26zgNmr4wf07elpjPobQWtBg\nCVAQ7nh5AgMBAAECggEAB6oTOs1DgPaF1ZN5qpHJHHfgx0Df9tZYInGlaLE/wtK1\nvjitwE8aHltqXVeEanZkiMs+BQPFQLncpss5QOLfQKjCaSfCB+Mq4LeB35ghib8z\nIh7AVmiOWggQw7B+x+hRAqU64notItpAY7cUAyhVnhzqwsvL18K4HCrIXBIUeqOa\nZGFOCJVoBfWl8SAdJZrOoiZeFsDGuVg2sNkhD7qffSJHYd+F7OkK7STAX2VPvM9j\nSwoG258g0HjURwT0RrkH9BxY25R4M2sD1WyDrud9FuugFneQ5Jbwbt6F3NaZ64vz\nAbJF/nbgSR4dwCr7fKWcnWlzEkqRaRQW3WFifaTJkQKBgQDteXsWyhiseOsKJT4p\nspJQLg+UYI68OvkJqqbtIUIP4XUV2ACAPwUr/Wq06XWK6Gpqucr7y3qos2/MOl3i\nfbceCMPdMccn5QpD3/eOVZ4orFPvxW674gBuAOg2mZvuHTTmY223CysmDXQddPP3\nDj5vxtUJN48EaNx43rklIKh4cQKBgQDdYulPbCpIQzGaIzY7VfHsSv8MCtSycZ/I\noU6VrpbD1BnXU0bFVlu6uZeSUGhaT7Jecvm8nQ0y9+Q9qjXOuAe1TSH6+XmYJQMy\nZo3EFeNipMJb1iO+UQmggpRcVNx5/yQivq8zXyhPotUevhC1B+2DONk7sFyATwci\nFuGF50hEiQKBgQCayhpfam/WzCJ4RHpWd51DQiLJln6zVsVJdcDExG7pJw5IpLj+\n3xUh7VcGgT4qwv/KfTxAEAvttrhiqJDVtxgLLa9tmKq16Gdegrg8QLaM0HcNzOU2\n9kNNcK3sGQg4lzUKDzlOnKsNbKuJH9h96vzrovDtxxcjyq4a4yJPfxARIQKBgQCp\nt0cGxPQRG7nt4SqVCEkDDWdCkxcFiUel5cs5wnL/wxzgTo4FgDOoDNkeqJenDEvA\nTkIXjwpsVU9a2p6PT9NQ8MWpAhFuSomN3MK3XNRJbec1wg76umM38oLL2Z5/w9Gu\n9SGYr01W54ycGbbzIRW6sB0Qvh3bmznrr0DKh0iGiQKBgQCxF31uQwFniRkrMZcY\nMcI5goSXAsq49Zf48Rm1m79vs753Y1qwK1V23AeWfIsnCNSW3VDRrMTVVJJTjtbR\n2Dgq7HF9glBbeO1itW3usVdv64ElVXMwnqe3zkBuvMPoX4SvkX301EDx48G5SEhT\n/0xDwtANq3zOLSZsWrIbA+4Ljw==\n-----END PRIVATE KEY-----\n"
```

## 設定手順

1. [Vercel ダッシュボード](https://vercel.com/dashboard) にログイン
2. 対象プロジェクトを選択
3. Settings → Environment Variables に移動
4. 上記の環境変数を一つずつ追加：
   - Production 環境を選択
   - `FIREBASE_PRIVATE_KEY` は "Sensitive" として設定

## Cloud Run デプロイ後の更新

Client Service がデプロイされた後、以下のコマンドで URL を取得：

```bash
./scripts/get-service-urls.sh
```

取得した URL で `NEXT_PUBLIC_GRAPHQL_ENDPOINT` と `NEXT_PUBLIC_WS_ENDPOINT` を更新してください。

## 確認事項

設定完了後、以下を確認：

1. Firebase Authentication の Google ログインが動作すること
2. GraphQL Playground が開けること（Client Service デプロイ後）
3. WebSocket 接続が確立されること（Client Service デプロイ後）
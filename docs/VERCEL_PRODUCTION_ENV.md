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
NEXT_PUBLIC_FIREBASE_API_KEY=[Firebase Console から取得]
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=[プロジェクトID].firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=[プロジェクトID]
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=[プロジェクトID].firebasestorage.app
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=[送信者ID]
NEXT_PUBLIC_FIREBASE_APP_ID=[アプリID]
```

### 3. Firebase Admin SDK (Secret - Sensitive として設定)

```
FIREBASE_PROJECT_ID=[プロジェクトID]
FIREBASE_CLIENT_EMAIL=[サービスアカウントメール]
FIREBASE_PRIVATE_KEY=[秘密鍵]
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
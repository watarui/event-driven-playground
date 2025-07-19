# Vercel 環境変数設定ガイド

このドキュメントでは、Vercel にフロントエンドをデプロイする際の環境変数設定について説明します。

## 必要な環境変数

Vercel のダッシュボードで以下の環境変数を設定してください。

### 1. WebSocket エンドポイント

```
NEXT_PUBLIC_WS_ENDPOINT=wss://client-service-prod-581148615576.asia-northeast1.run.app/socket/websocket
```

**注意**: Cloud Run サービスが正常にデプロイされてから、実際の URL に更新する必要があります。

### 2. Firebase Configuration (Public)

これらは公開可能な設定値です：

```
NEXT_PUBLIC_FIREBASE_API_KEY=AIzaSyB2tcXCHffMcLReMtFl3PLTARRawlyQys4
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=elixir-cqrs-es.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=elixir-cqrs-es
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=elixir-cqrs-es.firebasestorage.app
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=581148615576
NEXT_PUBLIC_FIREBASE_APP_ID=1:581148615576:web:0af8c9eab9e6f652b741ed
```

### 3. Firebase Admin SDK (Secret)

これらは秘密情報として設定する必要があります：

```
FIREBASE_PROJECT_ID=elixir-cqrs-es
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-fbsvc@elixir-cqrs-es.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY=<.env.production ファイルから取得>
```

**重要**: `FIREBASE_PRIVATE_KEY` は改行を含む複数行の値です。Vercel の環境変数設定時は、値全体をコピーして貼り付けてください。

## Vercel での設定方法

1. Vercel ダッシュボードにログイン
2. プロジェクトを選択
3. Settings → Environment Variables に移動
4. 各環境変数を追加：
   - Key: 環境変数名
   - Value: 環境変数の値
   - Environment: Production を選択

### 秘密情報の扱い

`FIREBASE_PRIVATE_KEY` のような秘密情報は、Vercel の "Sensitive" オプションを有効にして設定することを推奨します。

## デプロイ後の確認

環境変数を設定後、以下のコマンドでデプロイを実行：

```bash
cd frontend
vercel --prod
```

デプロイ完了後、以下を確認：

1. Firebase Authentication が正常に動作すること
2. WebSocket 接続が確立されること（Cloud Run サービスが起動している場合）
3. GraphQL エンドポイントへの接続が成功すること

## トラブルシューティング

### WebSocket 接続エラー

Cloud Run サービスがまだデプロイされていない場合、WebSocket 接続エラーが発生します。Cloud Run サービスのデプロイ完了後、正しい URL で環境変数を更新してください。

### Firebase 認証エラー

Firebase の設定が正しくない場合、以下を確認：

1. Firebase Console でプロジェクトが正しく設定されているか
2. Google 認証プロバイダが有効になっているか
3. 承認済みドメインに Vercel のドメインが追加されているか

### 環境変数が反映されない

環境変数を変更した後は、必ず再デプロイが必要です：

```bash
vercel --prod --force
```
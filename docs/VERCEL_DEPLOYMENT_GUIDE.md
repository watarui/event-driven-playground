# Vercel デプロイメントガイド

このドキュメントでは、CQRS Elixir プロジェクトのフロントエンドを Vercel にデプロイする手順を説明します。

## 前提条件

- バックエンドサービス（Query, Command, Client）が Google Cloud Run にデプロイ済み
- Vercel アカウントを持っている
- Firebase プロジェクトが設定済み

## バックエンドサービス URL

以下のサービスが Google Cloud Run にデプロイされています：

- **Client Service**: https://client-service-prod-581148615576.asia-northeast1.run.app
- **Query Service**: https://query-service-prod-581148615576.asia-northeast1.run.app
- **Command Service**: https://command-service-prod-581148615576.asia-northeast1.run.app

## 環境変数の設定

Vercel ダッシュボードで以下の環境変数を設定してください。

### 1. WebSocket エンドポイント

```
NEXT_PUBLIC_WS_ENDPOINT=wss://client-service-prod-581148615576.asia-northeast1.run.app/socket/websocket
```

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

### 3. Firebase Admin SDK (Secret - サーバーサイドレンダリング用)

これらは秘密情報として設定する必要があります：

```
FIREBASE_PROJECT_ID=elixir-cqrs-es
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-fbsvc@elixir-cqrs-es.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCmPrkHF3goChgu\nP+Z5aoZqpQj4w46+bWQ2yo2LC6a4ydMkEMRauNrCHBBQeaE3z6Pjq/Oe8halFiVd\nN5KtMupeLAb+pVXalwfYoK/PieYqaR+jwGW7cSEAQUl+Opyt9/KgZHRpnKcmNltg\ngol56pa3xbjHGGeKUMfedO4I/lkrtFa2qn88seXNY3vTbJPCFW9zJXjp9sVH3h28\nHA9wl5ad9WCUFWZvIhn3BDU0t/U0MOGhiMyS+M3eU2C8bWmhl67ZbdFq/bKwfh72\nrpR2Lm10gIr5LCy1NQsxeF2GtnV8PhLrm/7HP+r04q19pdhKlx1TZf81ovmgZDZY\nqeFzOSnBAgMBAAECggEAAhUuTpUMhe8BG8VyngSu6WyRjQoTDSEkDKjKbCxdQC/3\njyicngjLniZiabew0uAe6VitT9eiCjeLa/VFVW9hXRLHzMOwurhJj9JiNQpdg44s\nmiKlNWmvsouCZwjVgR7mf4p5wONqJckhjPAJSFQfVWDZCtXzRMu7gqFaSBXJAabd\n1/lWZxdKka2Vh1t2iAaA67VGj324LiSOV2R1WB4RX4PsieLVPWiaDjXl0pHEvmgY\nNGQotDvGczcAK2QN/e1Ef1kPnw0QUCScB+0d1E0qJYJ7J9Leawda50otiEx2inXZ\nw56dUp90qKUj9DUkZuvQfjvbxpXO+ZCwTIWKWCsNoQKBgQDW1G18bnrN+NB09vzz\ndYeUgjq5NVmuUvKVTpYLNi+I2zH5hNiFIrio6ZoCdGotU3Z8JBWpXlbcsLS0mwF9\nXRTDeOC69Z8qWUt5z+AAMqu39MBztX88Nn+Vli+9T1uuKPqgvqdPvSFdzKU3IAkN\nYaeL2AjyxgMtgJA5MYaRlujuuQKBgQDGGrhu4bYMFBAuohBbHnv+8HCmWYjWxSjF\nS6/hBhZQlHkk6h9Xdlh1xT/Isxfu75+VBpPdDQYgZpbp4dmFNU76OHwWVkDioIc1\nT3elyM3m81n2J2GeKVA78ugyzR722ICkuuloadttjEjYu2XUrVDSnUqUmoEVkuX1\nmrC3sTJPSQKBgDEQo1DgCrwwL6wHHQ6dsTGB7NeQD8N4vl7LbAlzfrfLGEbcyHbf\nzz0E3V/iJr3jahRASZI9MamF0j/NhzGSqMNcQDdzEb8iVdKkX4ysBfwlsi67LSwb\nZlhLzOt3zICia1t7L8tObuh1bOaCMo8T1qhh1ulbwC4MRuRJI2rtBJZBAoGBAMJ6\nHs7zk/TdiVlOTgI1tgJ7ZgtYYCZ/HNw6ximBAU0PxLHBiQ0iqArNniVX88njwWTa\nNTRPgdEzBToLNrA3uhWYd/CxsjcI4lMqdUnyDHiKM6mb1ZAf/J0thFfC2H/54KhW\nuaaALSKpEiZ6KaiUkICCW2HxH4HfWRM4Tf223a3JAoGABnEk5DJtMH6Z6OnWQhnF\nw4xzbw8ZyknIxCy44ZtMnIPu1Z5Qse6NHmNpK0x/hmi2ZeAr3KFtY71yGKpgrwIn\n25zfKU1Z8dcDdSblelH77I08PwWdoO3mD/oOBhWKtrJ04uJVmU+VoRmJZXyx4x9Y\nm9neCpVR10TopZfqByPRtsQ=\n-----END PRIVATE KEY-----\n"
```

**重要**: `FIREBASE_PRIVATE_KEY` は改行を含む複数行の値です。Vercel の環境変数設定時は、値全体をコピーして貼り付けてください。

## Vercel での設定手順

### 1. Vercel CLI を使用したデプロイ（推奨）

```bash
# frontend ディレクトリに移動
cd frontend

# Vercel CLI がインストールされていない場合
npm i -g vercel

# Vercel にログイン
vercel login

# プロジェクトをリンク（初回のみ）
vercel link

# 環境変数を設定
# 各環境変数を個別に設定
vercel env add NEXT_PUBLIC_WS_ENDPOINT production
vercel env add NEXT_PUBLIC_FIREBASE_API_KEY production
vercel env add NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN production
vercel env add NEXT_PUBLIC_FIREBASE_PROJECT_ID production
vercel env add NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET production
vercel env add NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID production
vercel env add NEXT_PUBLIC_FIREBASE_APP_ID production
vercel env add FIREBASE_PROJECT_ID production
vercel env add FIREBASE_CLIENT_EMAIL production
vercel env add FIREBASE_PRIVATE_KEY production

# 本番環境にデプロイ
vercel --prod
```

### 2. Vercel ダッシュボードを使用した設定

1. [Vercel ダッシュボード](https://vercel.com/dashboard) にログイン
2. プロジェクトを選択（まだない場合は新規作成）
3. **Settings** → **Environment Variables** に移動
4. 各環境変数を追加：
   - **Key**: 環境変数名
   - **Value**: 環境変数の値
   - **Environment**: Production を選択
   - **Sensitive**: `FIREBASE_PRIVATE_KEY` は有効にする

### 3. GitHub 統合を使用したデプロイ

1. GitHub リポジトリを Vercel にインポート
2. **Root Directory** を `frontend` に設定
3. **Environment Variables** で上記の変数を設定
4. デプロイを実行

## デプロイ後の確認

### 1. Firebase Authentication の確認

1. デプロイされた URL にアクセス
2. Google ログインボタンをクリック
3. 正常にログインできることを確認

### 2. GraphQL 接続の確認

ブラウザの開発者ツールで以下を確認：

- `/graphql` へのリクエストが成功している
- WebSocket 接続が確立されている（`wss://` で始まる URL）

### 3. Firebase の承認済みドメイン設定

Firebase Console で以下を設定：

1. [Firebase Console](https://console.firebase.google.com) にアクセス
2. **Authentication** → **Settings** → **Authorized domains**
3. Vercel のドメインを追加：
   - `your-app.vercel.app`
   - カスタムドメインを使用している場合はそれも追加

## トラブルシューティング

### CORS エラーが発生する場合

Client Service の CORS 設定を確認。必要に応じて Vercel のドメインを許可リストに追加。

### WebSocket 接続エラー

- Cloud Run サービスが起動していることを確認
- WebSocket エンドポイントの URL が正しいことを確認
- ブラウザの開発者ツールでエラーメッセージを確認

### Firebase 認証エラー

- Firebase プロジェクトの設定を確認
- Google 認証プロバイダが有効になっているか確認
- 承認済みドメインに Vercel のドメインが追加されているか確認

### 環境変数が反映されない

環境変数を変更した後は、必ず再デプロイが必要：

```bash
vercel --prod --force
```

## 関連ドキュメント

- [DEPLOYMENT_STATUS_20250116.md](./DEPLOYMENT_STATUS_20250116.md) - バックエンドのデプロイ状況
- [VERCEL_ENV_SETUP.md](./VERCEL_ENV_SETUP.md) - 環境変数設定の詳細
- [frontend/.env.example](../frontend/.env.example) - 環境変数のテンプレート
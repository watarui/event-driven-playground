# 本番環境デプロイメントガイド

## 前提条件

- Google Cloud プロジェクトがセットアップ済み
- gcloud CLI がインストール・認証済み
- Terraform がインストール済み
- Firebase プロジェクトがセットアップ済み
- Vercel アカウントがセットアップ済み

## 1. インフラストラクチャのセットアップ

### 1.1 Terraform での環境構築

```bash
cd terraform/environments/prod
terraform init
terraform plan
terraform apply
```

### 1.2 データベースのマイグレーション

各サービスのマイグレーションジョブが自動的に実行されます。
手動で実行する場合：

```bash
# Command Service
gcloud run jobs execute command-service-migrate --region=asia-northeast1

# Query Service  
gcloud run jobs execute query-service-migrate --region=asia-northeast1
```

## 2. バックエンドサービスのデプロイ

### 2.1 Docker イメージのビルド

```bash
# すべてのサービスをビルド
gcloud builds submit --config=cloudbuild.yaml

# 個別にビルド
gcloud builds submit --config=cloudbuild-command.yaml
gcloud builds submit --config=cloudbuild-query.yaml
gcloud builds submit --config=cloudbuild-client.yaml
```

### 2.2 Cloud Run へのデプロイ

Terraform で自動的にデプロイされますが、手動更新の場合：

```bash
# Command Service
gcloud run services update command-service-prod \
  --image=asia-northeast1-docker.pkg.dev/${PROJECT_ID}/elixir-cqrs/command-service:latest \
  --region=asia-northeast1

# Query Service
gcloud run services update query-service-prod \
  --image=asia-northeast1-docker.pkg.dev/${PROJECT_ID}/elixir-cqrs/query-service:latest \
  --region=asia-northeast1

# Client Service
gcloud run services update client-service-prod \
  --image=asia-northeast1-docker.pkg.dev/${PROJECT_ID}/elixir-cqrs/client-service:latest \
  --region=asia-northeast1
```

## 3. フロントエンドのデプロイ (Vercel)

### 3.1 環境変数の設定

Vercel ダッシュボードで以下の環境変数を設定：

```
NEXT_PUBLIC_FIREBASE_API_KEY=your-api-key
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=your-project.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=your-project-id
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=your-project.appspot.com
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=your-sender-id
NEXT_PUBLIC_FIREBASE_APP_ID=your-app-id
NEXT_PUBLIC_GOOGLE_OAUTH_CLIENT_ID=your-oauth-client-id.apps.googleusercontent.com
```

### 3.2 デプロイ

```bash
cd frontend
vercel --prod
```

## 4. Firebase 認証の設定

### 4.1 Google OAuth プロバイダーの有効化

1. Firebase Console → Authentication → Sign-in method
2. Google プロバイダーを有効化
3. OAuth クライアント ID を設定

### 4.2 承認済みドメインの追加

1. Firebase Console → Authentication → Settings → Authorized domains
2. Vercel のドメインを追加：
   - `elixir-cqrs.vercel.app`
   - `elixir-cqrs-*.vercel.app`

### 4.3 Google Cloud Console での設定

1. APIs & Services → Credentials
2. OAuth 2.0 Client IDs で該当のクライアントを編集
3. Authorized redirect URIs に追加：
   - `https://elixir-cqrs.vercel.app/__/auth/handler`
   - `https://your-project.firebaseapp.com/__/auth/handler`

## 5. 動作確認

### 5.1 ヘルスチェック

```bash
# 各サービスのヘルスチェック
curl https://command-service-prod-${PROJECT_NUMBER}.asia-northeast1.run.app/health
curl https://query-service-prod-${PROJECT_NUMBER}.asia-northeast1.run.app/health
curl https://client-service-prod-${PROJECT_NUMBER}.asia-northeast1.run.app/health
```

### 5.2 GraphQL エンドポイント

```bash
# GraphiQL インターフェース
open https://elixir-cqrs.vercel.app/graphiql

# GraphQL クエリテスト
curl -X POST https://client-service-prod-${PROJECT_NUMBER}.asia-northeast1.run.app/graphql \
  -H "Content-Type: application/json" \
  -d '{"query":"{ categories { id name } }"}'
```

## 6. トラブルシューティング

### 6.1 ログの確認

```bash
# Cloud Run のログ
gcloud run services logs read command-service-prod --region=asia-northeast1 --limit=50
gcloud run services logs read query-service-prod --region=asia-northeast1 --limit=50
gcloud run services logs read client-service-prod --region=asia-northeast1 --limit=50

# ビルドログ
gcloud builds list --limit=5
gcloud builds log BUILD_ID
```

### 6.2 よくある問題

#### スキーマプレフィックスエラー
```
relation "events" does not exist
```
→ SQL クエリでスキーマプレフィックスを指定: `event_store.events`

#### タイムアウトエラー
```
Failed to list categories: :timeout
```
→ PubSub のタイムアウト設定を確認、Query Service が起動しているか確認

#### CORS エラー
```
Access to XMLHttpRequest blocked by CORS policy
```
→ Client Service の endpoint.ex で CORS 設定を確認

#### Firebase 認証エラー
```
401 invalid_client
```
→ OAuth クライアント ID が正しいか確認、改行文字が含まれていないか確認

## 7. メンテナンス

### 7.1 データベースバックアップ

Cloud SQL の自動バックアップが設定されていますが、手動バックアップ：

```bash
gcloud sql backups create --instance=elixir-cqrs-postgres
```

### 7.2 ログの監視

Cloud Logging でログを監視：
```bash
gcloud logging read "resource.type=cloud_run_revision" --limit=50 --format=json
```

### 7.3 スケーリング設定

Terraform で設定済みですが、手動調整：
```bash
gcloud run services update SERVICE_NAME \
  --min-instances=1 \
  --max-instances=10 \
  --region=asia-northeast1
```

## 8. ロールバック手順

### 8.1 Cloud Run のロールバック

```bash
# 前のリビジョンを確認
gcloud run revisions list --service=SERVICE_NAME --region=asia-northeast1

# トラフィックを前のリビジョンに切り替え
gcloud run services update-traffic SERVICE_NAME \
  --to-revisions=REVISION_NAME=100 \
  --region=asia-northeast1
```

### 8.2 データベースのロールバック

```bash
# バックアップからリストア
gcloud sql backups restore BACKUP_ID --restore-instance=elixir-cqrs-postgres
```

## 9. 監視とアラート

### 9.1 Cloud Monitoring

- CPU 使用率
- メモリ使用率
- リクエストレイテンシ
- エラー率

### 9.2 アラート設定

Terraform で基本的なアラートが設定されています。
追加のアラートは Cloud Console から設定できます。
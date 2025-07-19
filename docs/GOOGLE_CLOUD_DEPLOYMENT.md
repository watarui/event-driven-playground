# Google Cloud デプロイメントガイド

## 概要

このガイドでは、CQRS アプリケーションを Google Cloud Platform にデプロイする手順を説明します。

### アーキテクチャ

- **コンテナ実行**: Google Cloud Run
- **メッセージング**: Google Cloud Pub/Sub
- **データベース**: Supabase (PostgreSQL)
- **認証**: Firebase Authentication
- **フロントエンド**: Vercel
- **監視**: Cloud Monitoring & Cloud Logging
- **インフラ管理**: Terraform

## 前提条件

### 必要なツール

```bash
# Google Cloud CLI
brew install google-cloud-sdk

# Terraform
brew install terraform

# Docker
brew install docker

# その他
brew install jq
```

### アカウントとプロジェクト

1. Google Cloud アカウント
2. Supabase アカウント
3. Firebase プロジェクト（Google Cloud プロジェクトと同じ）
4. Vercel アカウント

## セットアップ手順

### 1. Google Cloud プロジェクトの準備

```bash
# プロジェクトIDを設定
export PROJECT_ID="your-project-id"
export REGION="asia-northeast1"

# gcloud の初期化
gcloud init

# プロジェクトを作成（新規の場合）
gcloud projects create $PROJECT_ID --name="CQRS Demo"

# プロジェクトを設定
gcloud config set project $PROJECT_ID

# 請求アカウントをリンク
gcloud beta billing accounts list
gcloud beta billing projects link $PROJECT_ID --billing-account=BILLING_ACCOUNT_ID

# デフォルトリージョンを設定
gcloud config set compute/region $REGION
```

### 2. Supabase データベースのセットアップ

1. [Supabase Dashboard](https://app.supabase.com) にログイン
2. 新しいプロジェクトを作成
3. プロジェクト設定から以下を取得：
   - Project URL
   - Service Role Key（秘密鍵）

4. SQL エディタで以下を実行：

```sql
-- スキーマの作成
CREATE SCHEMA IF NOT EXISTS event_store;
CREATE SCHEMA IF NOT EXISTS command;
CREATE SCHEMA IF NOT EXISTS query;

-- 権限の設定
GRANT ALL ON SCHEMA event_store TO service_role;
GRANT ALL ON SCHEMA command TO service_role;
GRANT ALL ON SCHEMA query TO service_role;
```

### 3. Firebase Authentication のセットアップ

```bash
# Firebase プロジェクトを作成（Google Cloud プロジェクトと同じ ID）
firebase projects:create $PROJECT_ID

# Firebase CLI でログイン
firebase login

# プロジェクトを選択
firebase use $PROJECT_ID

# Authentication を有効化
firebase init auth
```

Firebase Console で：
1. Authentication → Sign-in method
2. Google を有効化
3. プロジェクト設定から Firebase 設定を取得

### 4. Terraform による環境構築

```bash
cd terraform/environments/dev

# terraform.tfvars を作成
cat > terraform.tfvars <<EOF
project_id  = "${PROJECT_ID}"
region      = "${REGION}"
environment = "dev"

# Supabase configuration
supabase_url         = "https://your-project.supabase.co"
supabase_service_key = "your-supabase-service-key"

# Firebase configuration  
firebase_config = {
  api_key     = "your-firebase-api-key"
  auth_domain = "${PROJECT_ID}.firebaseapp.com"
  project_id  = "${PROJECT_ID}"
}

enable_monitoring = true
EOF

# Terraform を初期化
terraform init

# 実行計画を確認
terraform plan

# インフラを構築
terraform apply
```

### 5. アプリケーションのビルドとデプロイ

```bash
# Artifact Registry に認証
gcloud auth configure-docker ${REGION}-docker.pkg.dev

# レジストリURLを取得
export REGISTRY_URL=$(terraform output -raw artifact_registry_url)

# Docker イメージをビルド
for service in command-service query-service client-service; do
  docker build -f apps/${service//-/_}/Dockerfile -t $REGISTRY_URL/$service:latest .
  docker push $REGISTRY_URL/$service:latest
done

# Cloud Run にデプロイ（Terraform が自動的に最新イメージを使用）
terraform apply -auto-approve
```

### 6. フロントエンドのデプロイ（Vercel）

```bash
cd frontend

# 環境変数を設定
cat > .env.production <<EOF
NEXT_PUBLIC_GRAPHQL_ENDPOINT=$(terraform output -raw cloud_run_urls | jq -r '.["client-service"]')/graphql
NEXT_PUBLIC_WS_ENDPOINT=wss://$(terraform output -raw cloud_run_urls | jq -r '.["client-service"]' | sed 's|https://||')/socket/websocket
NEXT_PUBLIC_FIREBASE_API_KEY=your-firebase-api-key
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=${PROJECT_ID}.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=${PROJECT_ID}
EOF

# Vercel にデプロイ
vercel --prod
```

## 環境変数

### Cloud Run サービス

自動的に設定される環境変数：
- `GOOGLE_CLOUD_PROJECT`: プロジェクト ID
- `DATABASE_URL`: Supabase 接続文字列（Secret Manager から）
- `FIREBASE_PROJECT_ID`: Firebase プロジェクト ID
- `MIX_ENV`: prod

### ローカル開発

`.env.local` ファイル：
```bash
GOOGLE_CLOUD_PROJECT=your-project-id
DATABASE_URL=postgresql://...
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_API_KEY=your-api-key
```

## 運用

### ログの確認

```bash
# Cloud Run のログ
gcloud run services logs read command-service-dev --region=$REGION

# Pub/Sub のメトリクス
gcloud monitoring metrics-descriptors list --filter="metric.type:pubsub"
```

### モニタリング

1. [Cloud Console](https://console.cloud.google.com) にアクセス
2. Monitoring → Dashboards → "CQRS Application Dashboard - dev"

### スケーリング設定の変更

```bash
# terraform.tfvars を編集
services = {
  command-service = {
    memory    = "1Gi"
    cpu       = "2"
    min_scale = 1
    max_scale = 100
    port      = 8080
  }
  # ...
}

# 適用
terraform apply
```

### デバッグ

```bash
# サービスの状態確認
gcloud run services describe command-service-dev --region=$REGION

# Pub/Sub サブスクリプションの確認
gcloud pubsub subscriptions list

# Secret Manager の確認
gcloud secrets list
```

## CI/CD パイプライン

### GitHub Actions

`.github/workflows/deploy.yml`:
```yaml
name: Deploy to Cloud Run

on:
  push:
    branches: [main]

env:
  PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}
  REGION: asia-northeast1

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - id: auth
      uses: google-github-actions/auth@v2
      with:
        credentials_json: ${{ secrets.GCP_SA_KEY }}
    
    - name: Set up Cloud SDK
      uses: google-github-actions/setup-gcloud@v2
    
    - name: Configure Docker
      run: gcloud auth configure-docker ${{ env.REGION }}-docker.pkg.dev
    
    - name: Build and Push
      run: |
        for service in command-service query-service client-service; do
          docker build -f apps/${service//-/_}/Dockerfile \
            -t ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/elixir-cqrs/$service:${{ github.sha }} .
          docker push ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/elixir-cqrs/$service:${{ github.sha }}
        done
    
    - name: Deploy to Cloud Run
      run: |
        for service in command-service query-service client-service; do
          gcloud run deploy $service-prod \
            --image ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/elixir-cqrs/$service:${{ github.sha }} \
            --region ${{ env.REGION }}
        done
```

## コスト最適化

### 推定月額コスト（軽量利用）

- Cloud Run: $0-10（無料枠内）
- Cloud Pub/Sub: $0-5（無料枠内）
- Supabase: $0（無料プラン）
- Firebase Auth: $0（無料枠内）
- Vercel: $0（Hobby プラン）

### コスト削減のヒント

1. Cloud Run の min_scale を 0 に設定
2. 開発環境は使用時のみ起動
3. Cloud Logging の保持期間を短縮
4. 不要なリソースは Terraform で削除

```bash
# 開発環境の削除
terraform destroy
```

## トラブルシューティング

### よくある問題

1. **Cloud Run がタイムアウトする**
   - ヘルスチェックエンドポイントの確認
   - startup_probe の設定を調整

2. **Pub/Sub メッセージが届かない**
   - サブスクリプションの確認
   - Service Account の権限確認

3. **データベース接続エラー**
   - Supabase の接続制限確認
   - SSL 設定の確認

### サポート

- [Google Cloud ドキュメント](https://cloud.google.com/docs)
- [Supabase ドキュメント](https://supabase.com/docs)
- [Firebase ドキュメント](https://firebase.google.com/docs)
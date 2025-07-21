# デプロイガイド

## 概要

このガイドでは、Event Driven Playground を Google Cloud Platform (バックエンド) と Vercel (フロントエンド) にデプロイする手順を説明します。

## 前提条件

- Google Cloud プロジェクトが作成済み
- gcloud CLI がインストール・認証済み
- Terraform がインストール済み
- Vercel アカウントが作成済み
- GitHub リポジトリが設定済み

## バックエンドのデプロイ (Google Cloud)

### 1. 初期設定

```bash
# プロジェクトIDを設定
export PROJECT_ID=your-project-id
export REGION=asia-northeast1

# gcloud の設定
gcloud config set project $PROJECT_ID
gcloud config set compute/region $REGION
```

### 2. Firestore データベースの作成

```bash
# Firestore データベースを作成（初回のみ）
gcloud firestore databases create \
  --region=$REGION \
  --project=$PROJECT_ID
```

### 3. Firebase プロジェクトの設定

1. [Firebase Console](https://console.firebase.google.com) にアクセス
2. プロジェクトを追加（既存のGCPプロジェクトを使用）
3. Authentication を有効化
4. ウェブアプリを追加して設定情報を取得

### 4. Terraform での環境構築

```bash
cd terraform/environments/prod

# terraform.tfvars を作成
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars を編集して必要な値を設定

# Terraform の初期化
terraform init

# 実行計画の確認
terraform plan

# リソースの作成
terraform apply
```

### 5. Docker イメージのビルドとプッシュ

```bash
cd ../../../  # プロジェクトルートに戻る

# Cloud Build でイメージをビルド
gcloud builds submit \
  --config=build/cloudbuild/optimized.yaml \
  --project=$PROJECT_ID
```

### 6. Cloud Run サービスのデプロイ

Terraform でサービスが作成されているので、イメージを更新：

```bash
# 各サービスを更新
gcloud run deploy client-service \
  --image=asia-northeast1-docker.pkg.dev/$PROJECT_ID/event-driven-playground/client-service:latest \
  --region=$REGION

gcloud run deploy command-service \
  --image=asia-northeast1-docker.pkg.dev/$PROJECT_ID/event-driven-playground/command-service:latest \
  --region=$REGION

gcloud run deploy query-service \
  --image=asia-northeast1-docker.pkg.dev/$PROJECT_ID/event-driven-playground/query-service:latest \
  --region=$REGION
```

## フロントエンドのデプロイ (Vercel)

### 1. 環境変数の設定

Vercel ダッシュボードで以下の環境変数を設定：

```
NEXT_PUBLIC_GRAPHQL_ENDPOINT=https://client-service-xxxxx-an.a.run.app/graphql
NEXT_PUBLIC_FIREBASE_API_KEY=your-firebase-api-key
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=your-project.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=your-project-id
```

### 2. Vercel へのデプロイ

```bash
cd frontend

# Vercel CLI を使用する場合
npm i -g vercel
vercel

# または GitHub 連携を設定している場合は自動デプロイ
```

## CI/CD パイプライン

### GitHub Actions の設定

`.github/workflows/deploy.yml` が設定されており、以下のトリガーで自動デプロイされます：

- `main` ブランチへのプッシュ時
- タグ作成時（`v*` パターン）

### 必要な GitHub Secrets

以下のシークレットを GitHub リポジトリに設定：

```
GCP_PROJECT_ID          # Google Cloud プロジェクトID
GCP_SA_KEY             # サービスアカウントキー（JSON）
VERCEL_TOKEN           # Vercel APIトークン
VERCEL_ORG_ID          # Vercel 組織ID
VERCEL_PROJECT_ID      # Vercel プロジェクトID
```

## 本番環境の監視

### Cloud Monitoring

Terraform で自動的に以下のアラートが設定されます：

- メモリ使用率が80%を超えた場合
- データベース接続エラーが発生した場合
- リクエストレイテンシが閾値を超えた場合

### ログの確認

```bash
# Cloud Run のログを確認
gcloud logging read "resource.type=cloud_run_revision" \
  --limit=50 \
  --format=json

# 特定のサービスのログ
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=client-service" \
  --limit=50
```

## トラブルシューティング

### Cloud Run サービスが起動しない

1. ログを確認
```bash
gcloud run services describe client-service --region=$REGION
```

2. 環境変数が正しく設定されているか確認
3. ポート設定が正しいか確認（PORT環境変数）

### Firestore 接続エラー

1. サービスアカウントの権限を確認
```bash
gcloud projects get-iam-policy $PROJECT_ID
```

2. Firestore API が有効になっているか確認
```bash
gcloud services list --enabled | grep firestore
```

### デプロイのロールバック

```bash
# 前のリビジョンにロールバック
gcloud run services update-traffic client-service \
  --to-revisions=PREV=100 \
  --region=$REGION
```

## コスト最適化

### 開発環境での節約

- Cloud Run の最小インスタンス数を0に設定
- 使用しない時は `terraform destroy` でリソースを削除

### 本番環境での最適化

- Cloud Run の同時実行数を調整
- Firestore の使用量を監視
- Cloud CDN を活用してエグレス料金を削減
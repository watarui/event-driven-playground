# GitHub Actions 権限設定ガイド

## 問題

GitHub Actions で Cloud Run Jobs の実行時に以下のエラーが発生：
```
PERMISSION_DENIED: Permission 'run.jobs.run' denied on resource
```

## 解決方法

### 1. GitHub Actions が使用しているサービスアカウントを確認

1. GitHub リポジトリの Settings → Secrets and variables → Actions を開く
2. `WIF_SERVICE_ACCOUNT` シークレットの値を確認
3. このサービスアカウントに必要な権限を付与する

現在のプロジェクトでは：
- サービスアカウント: `event-driven-playground-runner@event-driven-playground-prod.iam.gserviceaccount.com`
- Workload Identity Pool: `github`
- Provider: `github-provider`

### 2. 必要な権限

GitHub Actions のサービスアカウントには以下の権限が必要：

- `roles/run.developer` - Cloud Run Jobs の実行権限
- `roles/run.admin` - Cloud Run Jobs の作成/更新権限
- `roles/cloudbuild.builds.builder` - Cloud Build の実行権限
- `roles/artifactregistry.writer` - Artifact Registry への書き込み権限

### 3. Google Cloud Console での権限追加

1. [Google Cloud Console](https://console.cloud.google.com/) にアクセス
2. IAM & Admin → IAM を開く
3. GitHub Actions のサービスアカウントを見つける
4. 編集ボタンをクリックして必要なロールを追加

### 4. gcloud コマンドでの権限追加

```bash
# サービスアカウントのメールアドレスを設定
SERVICE_ACCOUNT_EMAIL="your-service-account@your-project.iam.gserviceaccount.com"
PROJECT_ID="event-driven-playground-prod"

# Cloud Run Developer ロールを追加
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/run.developer"

# Cloud Run Admin ロールを追加
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/run.admin"
```

## 注意事項

- Workload Identity Federation を使用している場合、正しいサービスアカウントを特定することが重要
- 権限の変更は即座に反映されますが、キャッシュのため数分かかる場合があります
- 最小権限の原則に従い、必要な権限のみを付与してください
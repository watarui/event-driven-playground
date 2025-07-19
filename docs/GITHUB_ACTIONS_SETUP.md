# GitHub Actions セットアップガイド

## 概要

このドキュメントでは、GitHub Actions を使用した CI/CD パイプラインのセットアップ方法を説明します。

## ワークフローの概要

### 1. CI ワークフロー (`.github/workflows/ci.yml`)

- **トリガー**: PR や main 以外のブランチへのプッシュ
- **実行内容**:
  - Elixir テストの実行
  - コードフォーマットのチェック
  - Docker イメージのビルドテスト
  - Frontend のビルドと lint

### 2. CD ワークフロー (`.github/workflows/deploy-production.yml`)

- **トリガー**: main ブランチへのプッシュまたはマージ
- **実行内容**:
  - Google Cloud への認証
  - Docker イメージのビルドとプッシュ
  - データベースマイグレーション
  - Cloud Run サービスのデプロイ
  - ヘルスチェックとトラフィック切り替え

## セットアップ手順

### 1. Workload Identity Federation の設定

GitHub Actions から Google Cloud に安全にアクセスするため、Workload Identity Federation を設定します。

```bash
# 変数設定
export PROJECT_ID="elixir-cqrs-prod"
export GITHUB_REPO="your-github-username/elixir-cqrs"
export SERVICE_ACCOUNT_NAME="github-actions-deployer"
export WORKLOAD_IDENTITY_POOL="github-actions-pool"
export WORKLOAD_IDENTITY_PROVIDER="github-actions-provider"

# Workload Identity Pool の作成
gcloud iam workload-identity-pools create ${WORKLOAD_IDENTITY_POOL} \
  --location="global" \
  --display-name="GitHub Actions Pool" \
  --project=${PROJECT_ID}

# Workload Identity Provider の作成
gcloud iam workload-identity-pools providers create-oidc ${WORKLOAD_IDENTITY_PROVIDER} \
  --location="global" \
  --workload-identity-pool=${WORKLOAD_IDENTITY_POOL} \
  --display-name="GitHub Actions Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --project=${PROJECT_ID}

# サービスアカウントの作成
gcloud iam service-accounts create ${SERVICE_ACCOUNT_NAME} \
  --display-name="GitHub Actions Deployer" \
  --project=${PROJECT_ID}

# 必要な権限の付与
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/cloudbuild.builds.editor"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"

# Workload Identity のバインディング
gcloud iam service-accounts add-iam-policy-binding \
  ${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${WORKLOAD_IDENTITY_POOL}/attribute.repository/${GITHUB_REPO}" \
  --project=${PROJECT_ID}
```

### 2. GitHub Secrets の設定

GitHub リポジトリの Settings > Secrets and variables > Actions で以下のシークレットを設定：

```bash
# Workload Identity Provider の完全なリソース名を取得
WIF_PROVIDER=$(gcloud iam workload-identity-pools providers describe ${WORKLOAD_IDENTITY_PROVIDER} \
  --location="global" \
  --workload-identity-pool=${WORKLOAD_IDENTITY_POOL} \
  --format="value(name)" \
  --project=${PROJECT_ID})

# サービスアカウントのメールアドレス
WIF_SERVICE_ACCOUNT="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
```

GitHub Secrets に設定：
- `WIF_PROVIDER`: 上記で取得した Provider の完全なリソース名
- `WIF_SERVICE_ACCOUNT`: 上記で取得したサービスアカウントのメール
- `SLACK_WEBHOOK`: (Optional) Slack 通知用の Webhook URL

### 3. ワークフローの有効化

1. 作成したワークフローファイルをコミット：
   ```bash
   git add .github/workflows/
   git commit -m "Add GitHub Actions CI/CD workflows"
   git push origin feature/github-actions
   ```

2. PR を作成して CI ワークフローが動作することを確認

3. main ブランチにマージして CD ワークフローが動作することを確認

## オブザーバビリティの設定

### Google Cloud Logging

Cloud Run ではコンテナログが自動的に Cloud Logging に送信されます。
`Shared.Telemetry.GoogleCloudExporter` モジュールが構造化ログを出力します。

#### ログの確認

```bash
# サービスのログを表示
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=client-service" \
  --limit=50 \
  --format=json \
  --project=${PROJECT_ID}

# 特定のイベントタイプでフィルタ
gcloud logging read 'jsonPayload.eventType="command.dispatched"' \
  --limit=20 \
  --format="table(timestamp,jsonPayload.eventType,jsonPayload.metadata)" \
  --project=${PROJECT_ID}
```

### Google Cloud Monitoring

#### カスタムメトリクスの表示

1. [Cloud Console](https://console.cloud.google.com/monitoring) を開く
2. Metrics Explorer へ移動
3. Resource Type: "Cloud Run Revision" を選択
4. Metric: カスタムメトリクスは "custom.googleapis.com/elixir-cqrs/" プレフィックスで表示

#### アラートの設定

```bash
# エラー率が高い場合のアラート
gcloud alpha monitoring policies create \
  --notification-channels="${NOTIFICATION_CHANNEL_ID}" \
  --display-name="High Error Rate" \
  --condition-display-name="Error rate > 5%" \
  --condition-filter='resource.type="cloud_run_revision" AND metric.type="run.googleapis.com/request_count"' \
  --condition-threshold-value=0.05 \
  --condition-threshold-duration=300s
```

### ダッシュボードの作成

1. Cloud Console で Monitoring > Dashboards へ移動
2. "CREATE DASHBOARD" をクリック
3. 以下のウィジェットを追加：
   - Request Count (Cloud Run)
   - Request Latencies (Cloud Run)
   - Container CPU Utilization
   - Container Memory Utilization
   - Custom Metrics (アプリケーション固有)

## トラブルシューティング

### GitHub Actions が失敗する場合

1. **認証エラー**
   - WIF_PROVIDER と WIF_SERVICE_ACCOUNT が正しく設定されているか確認
   - サービスアカウントに必要な権限があるか確認

2. **ビルドエラー**
   - Docker イメージのビルドログを確認
   - 依存関係のバージョン競合をチェック

3. **デプロイエラー**
   - Cloud Run のサービスログを確認
   - ヘルスチェックが失敗していないか確認

### メトリクスが表示されない場合

1. `GoogleCloudExporter` が起動しているかログで確認
2. Cloud Monitoring API が有効か確認
3. サービスアカウントに Monitoring Metric Writer 権限があるか確認

## ベストプラクティス

1. **ブランチ戦略**
   - feature ブランチで開発
   - PR で CI を実行
   - main ブランチへのマージで自動デプロイ

2. **セキュリティ**
   - Workload Identity Federation でキーレス認証
   - 最小権限の原則に従った IAM 設定

3. **モニタリング**
   - アラートを設定して問題を早期発見
   - ダッシュボードでシステムの健全性を可視化

4. **ロールバック**
   - トラフィックを段階的に切り替え
   - 問題があれば前のバージョンに戻す

# デプロイメント進捗状況 - 2025/01/19

## 概要
`elixir-cqrs` から `event-driven-playground` への移行作業を実施中。Docker イメージのビルドは成功し、Terraform でのインフラ構築段階に入っています。

## 完了したタスク

### 1. API キーセキュリティの改善
- Firebase API キーをドキュメントから削除
- プレースホルダーに置き換え完了
  - `docs/VERCEL_ENV_SETUP.md`
  - `docs/VERCEL_DEPLOYMENT_GUIDE.md`

### 2. GitHub Actions の修正
- Slack 通知ステップを削除（Webhook URL が無効だったため）
- `.github/workflows/deploy-production.yml` の修正完了

### 3. Cloud Build の設定と Docker イメージのビルド
#### 初期の問題と解決
- **問題 1**: Cloud Build API が有効化されていない
  - **解決**: `gcloud services enable cloudbuild.googleapis.com` で有効化

- **問題 2**: Cloud Build サービスアカウントの権限不足
  - **解決**: 以下の権限を付与
    ```bash
    gcloud projects add-iam-policy-binding event-driven-playground-prod \
      --member="serviceAccount:741925348867@cloudbuild.gserviceaccount.com" \
      --role="roles/cloudbuild.builds.builder"
    
    gcloud projects add-iam-policy-binding event-driven-playground-prod \
      --member="serviceAccount:741925348867@cloudbuild.gserviceaccount.com" \
      --role="roles/storage.admin"
    
    gcloud projects add-iam-policy-binding event-driven-playground-prod \
      --member="serviceAccount:741925348867@cloudbuild.gserviceaccount.com" \
      --role="roles/artifactregistry.writer"
    ```

- **問題 3**: Dockerfile.base でのビルドエラー
  - HEX_HOME ディレクトリが存在しない
  - 依存関係の解決に失敗
  - **解決**: シンプルな Dockerfile に切り替え

#### 成功したビルド
- `cloudbuild-optimized.yaml` を修正して、メインの Dockerfile を使用
- 3つのサービスすべてのイメージをビルド成功
  - client-service: `sha256:fede383bb0d2e4af271f94bf7d7a657d35272e042086f5648d27de595e69e1b1`
  - command-service: `sha256:e9dd0d998c866ec0a1dbc5bb044cea07c6be764ab58a0ea3c682b351bb3e850f`
  - query-service: `sha256:23a4371e1b57a660649c47d7521d62c9d3909116eb014b8b9169b47888e5cf2c`
- タグ: `3d28c00` と `latest`

### 4. Terraform 設定の準備
- `terraform/environments/prod/main.tf` で Cloud Run モジュールのコメントを解除
- モニタリングモジュールのコメントも解除

## 現在の状況

### Terraform Apply でのエラー
既存のリソースとの競合により、以下のエラーが発生：
- Artifact Registry リポジトリが既に存在
- Service Account が既に存在
- Secret Manager のシークレットが既に存在
- Pub/Sub トピックが既に存在
- Firebase Identity Platform が既に有効化済み

### 解決策
段階的な Terraform インポートとアプライが必要：

1. 状態ファイルのバックアップ
   ```bash
   cp terraform.tfstate terraform.tfstate.backup
   ```

2. 基本リソースの適用
   ```bash
   terraform apply -target=google_project_service.required_apis \
     -target=google_artifact_registry_repository.event_driven_playground \
     -target=google_service_account.cloud_run_sa \
     -target=google_project_iam_member.cloud_run_roles
   ```

3. Secrets の適用
   ```bash
   terraform apply -target=google_secret_manager_secret.app_secrets
   ```

4. Secret versions の適用
   ```bash
   terraform apply -target=google_secret_manager_secret_version.app_secrets_version
   ```

5. 全リソースの適用
   ```bash
   terraform apply
   ```

## 今後のタスク

### 1. Terraform デプロイメントの完了
- [ ] 上記の段階的 apply を実行
- [ ] Cloud Run サービスのデプロイ確認
- [ ] ヘルスチェックの確認

### 2. Frontend のデプロイ
- [ ] Vercel へのデプロイ設定
- [ ] 環境変数の設定
- [ ] Firebase Authentication の接続確認

### 3. 動作確認
- [ ] GraphQL エンドポイントのテスト
- [ ] Pub/Sub メッセージングのテスト
- [ ] CQRS パターンの動作確認
- [ ] Saga パターンの動作確認

### 4. 監視とログの設定
- [ ] Cloud Monitoring ダッシュボードの確認
- [ ] ログの収集確認
- [ ] アラートの設定

## 重要な注意点

1. **Docker イメージ**: 既に Artifact Registry にプッシュ済み。再ビルドは不要。

2. **Terraform の状態**: 既存リソースとの競合を解決するため、段階的な適用が必要。

3. **サービスアカウント**: `event-driven-playground-runner@event-driven-playground-prod.iam.gserviceaccount.com` が既に存在。

4. **次回作業時**: `/Users/w/w/event-driven-playground/terraform/environments/prod` ディレクトリから作業を再開。

## 参考リンク
- プロジェクト ID: `event-driven-playground-prod`
- リージョン: `asia-northeast1`
- Artifact Registry: `asia-northeast1-docker.pkg.dev/event-driven-playground-prod/event-driven-playground/`

## トラブルシューティング履歴
1. Dockerfile.base での複雑なマルチステージビルドは、Elixir アンブレラプロジェクトでは依存関係の問題を引き起こしやすい
2. シンプルな Dockerfile アプローチの方が信頼性が高い
3. Cloud Build のログは `gcloud builds log [BUILD_ID] --project=event-driven-playground-prod` で確認可能
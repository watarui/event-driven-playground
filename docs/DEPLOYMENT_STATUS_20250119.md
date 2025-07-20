# デプロイメント進捗状況 - 2025/01/19

## 概要
`elixir-cqrs` から `event-driven-playground` への移行作業を実施中。全サービスのデプロイが完了し、正常に稼働しています。

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

### 5. データベース接続の修正
- Supabase のデータベース接続問題を解決
  - IPv4-only pooler URL の制限により、直接接続 URL に変更
  - パスワードを正しい値に更新
- マイグレーションを手動で実行
  - event_store スキーマのテーブルを作成
  - command と query スキーマも作成

### 6. Phoenix エンドポイント設定の修正
- Cloud Run でのポート設定問題を解決
  - `Shared.Config.endpoint_config` を修正
  - `http: [ip: {0, 0, 0, 0}, port: port]` 形式に変更
- コミット: `f885f16`

### 7. 全サービスのデプロイ完了
- **client-service**: https://client-service-741925348867.asia-northeast1.run.app
  - ヘルスチェック: ✅ 200 OK
  - 認証: 不要（公開アクセス可能）
  - GraphQL エンドポイント: ✅ 動作確認済み
- **command-service**: https://command-service-741925348867.asia-northeast1.run.app
  - ヘルスチェック: ✅ 200 OK
  - 認証: 必要（IAM 認証）
- **query-service**: https://query-service-741925348867.asia-northeast1.run.app
  - ヘルスチェック: ✅ 200 OK
  - 認証: 必要（IAM 認証）

### 8. データベーススキーマの完成
- **event_store スキーマ**: 全テーブル作成完了
- **command スキーマ**: categories, products テーブル作成完了
- **query スキーマ**: orders テーブル作成完了
- 全マイグレーション適用済み

### 9. Cloud Run Jobs でマイグレーション自動化
- マイグレーション用 Docker イメージ作成（Elixir 1.18）
- Cloud Run Job `database-migrate` を作成
- 実行コマンド: `gcloud run jobs execute database-migrate`
- 全スキーマのマイグレーションを自動実行

### 10. GitHub Actions の更新完了
- デプロイワークフローにマイグレーション実行ステップを追加
- マイグレーションイメージのビルドステップを追加
- `database-migrate` ジョブを実行するように修正

### 11. Frontend の Vercel デプロイ準備完了
- `vercel.json` を作成（bun 対応）
- TypeScript エラーを修正
- Firebase 依存関係の問題を解決
- Vercel デプロイガイドを更新

### 12. 監視とアラートの設定完了
- Google Cloud Monitoring の設定を追加
- メール通知チャンネルを設定
- カスタムアラートを追加：
  - データベース接続エラーアラート
  - 高メモリ使用率アラート
- 監視ダッシュボードを自動生成

## 現在の状況

### デプロイ完了
全サービスが Cloud Run に正常にデプロイされ、稼働中です：
- Docker イメージ: `f885f16` タグでビルド済み
- 環境変数とシークレットが正しく設定済み
- ヘルスチェックが全サービスで成功

## 今後のタスク

### 1. GitHub Actions の更新
- [x] デプロイワークフローにマイグレーション実行ステップを追加
- [x] `gcloud run jobs execute database-migrate` をデプロイ前に実行

### 2. Frontend のデプロイ
- [x] Vercel へのデプロイ設定
- [x] 環境変数の設定（VERCEL_ENV_SETUP.md を参照）
- [ ] Firebase Authentication の接続確認
- [ ] 実際に Vercel へデプロイ

### 3. 動作確認
- [ ] GraphQL エンドポイントのテスト
- [ ] Pub/Sub メッセージングのテスト
- [ ] CQRS パターンの動作確認
- [ ] Saga パターンの動作確認

### 4. 監視とログの設定
- [x] Cloud Monitoring ダッシュボードの設定
- [x] ログの収集設定
- [x] アラートの設定
- [ ] アラートメールアドレスを実際のアドレスに変更（現在は alerts@example.com）

## 重要な注意点

1. **Docker イメージ**: 統合 Dockerfile を使用してビルド。各サービスは異なるターゲットステージとして定義。

2. **データベース接続**: Supabase の pooler URL は IPv4-only のため、直接接続 URL を使用。

3. **ポート設定**: Cloud Run は PORT 環境変数を自動設定するため、アプリケーション側で読み取る。

4. **マイグレーション**: 今後のデプロイでは Cloud Run Jobs でマイグレーションを自動化する必要がある。

## 参考リンク
- プロジェクト ID: `event-driven-playground-prod`
- リージョン: `asia-northeast1`
- Artifact Registry: `asia-northeast1-docker.pkg.dev/event-driven-playground-prod/event-driven-playground/`

## トラブルシューティング履歴
1. Dockerfile.base での複雑なマルチステージビルドは、Elixir アンブレラプロジェクトでは依存関係の問題を引き起こしやすい
2. シンプルな Dockerfile アプローチの方が信頼性が高い
3. Cloud Build のログは `gcloud builds log [BUILD_ID] --project=event-driven-playground-prod` で確認可能
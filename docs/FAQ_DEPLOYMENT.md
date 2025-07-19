# デプロイメント FAQ

## よくある質問と回答

### Q1: どのように環境変数を設定すればいいですか？

**A:** システムによって異なります：

#### バックエンド (Elixir/Phoenix)
- **ローカル開発**: シェルで直接環境変数を設定するか、起動時に指定
  ```bash
  # オプション1: シェルで設定
  export MIX_ENV=dev
  export PORT=4000
  iex -S mix phx.server
  
  # オプション2: 起動時に指定
  MIX_ENV=dev PORT=4000 iex -S mix phx.server
  ```
- **本番環境**: Cloud Run が自動的に設定（Terraform経由）

#### フロントエンド (Next.js/Bun)
| 環境 | ファイル | 場所 | 用途 |
|------|---------|------|------|
| テンプレート | `.env.example` | `frontend/` | フロントエンド設定テンプレート |
| ローカル開発 | `.env.local` | `frontend/` | Next.jsフロントエンド用 |
| 本番環境 | `.env.production` | `frontend/` | Vercelデプロイ用 |
| 本番環境 | `terraform.tfvars` | `terraform/environments/dev/` | インフラ構築用 |

### Q2: Firebase と Supabase の設定値はどこで確認できますか？

**A:** 各サービスの管理画面で確認できます：

**Supabase:**
1. https://app.supabase.com にログイン
2. プロジェクトを選択
3. 左メニュー「Settings」→「API」
   - `URL` = `supabase_url`
   - `service_role` キー = `supabase_service_key`
4. 左メニュー「Settings」→「Database」
   - `Connection string` = `DATABASE_URL`

**Firebase:**
1. https://console.firebase.google.com にログイン
2. プロジェクトを選択
3. 歯車アイコン → プロジェクトの設定
4. 下部の「マイアプリ」セクション
   - SDK設定が表示されている

### Q3: ローカルでは動くのに本番環境でエラーになります

**A:** 以下を確認してください：

1. **環境変数の設定ミス**
   ```bash
   # Secret Manager の値を確認
   gcloud secrets versions access latest --secret="supabase-url"
   ```

2. **APIが有効化されていない**
   ```bash
   gcloud services enable run.googleapis.com
   gcloud services enable pubsub.googleapis.com
   gcloud services enable secretmanager.googleapis.com
   ```

3. **IAM権限の不足**
   ```bash
   # Service Accountの権限を確認
   gcloud projects get-iam-policy $PROJECT_ID
   ```

### Q4: データベース接続エラーが発生します

**A:** Supabaseの接続文字列を確認：

1. **正しい形式か確認**
   ```
   postgresql://postgres.[project-ref]:[password]@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres
   ```

2. **スキーマが作成されているか確認**
   - Supabase SQL Editorで確認：
   ```sql
   SELECT schema_name FROM information_schema.schemata 
   WHERE schema_name IN ('event_store', 'command', 'query');
   ```

3. **接続プーリングモードを確認**
   - Supabaseダッシュボード → Settings → Database
   - Connection pooling が有効か確認

### Q5: Terraform apply でエラーが出ます

**A:** よくあるエラーと対処法：

1. **「API not enabled」エラー**
   ```bash
   # 必要なAPIをすべて有効化
   gcloud services enable \
     run.googleapis.com \
     pubsub.googleapis.com \
     secretmanager.googleapis.com \
     artifactregistry.googleapis.com \
     cloudbuild.googleapis.com \
     firebase.googleapis.com \
     identitytoolkit.googleapis.com
   ```

2. **「Permission denied」エラー**
   ```bash
   # 現在のユーザーに必要な権限を付与
   gcloud projects add-iam-policy-binding $PROJECT_ID \
     --member="user:your-email@example.com" \
     --role="roles/owner"
   ```

3. **「Resource already exists」エラー**
   ```bash
   # 既存のリソースをインポート
   terraform import google_artifact_registry_repository.event_driven_playground \
     projects/$PROJECT_ID/locations/$REGION/repositories/event-driven-playground
   ```

### Q6: Docker イメージのプッシュで認証エラーが出ます

**A:** Docker の認証設定を更新：

```bash
# 1. gcloud の再認証
gcloud auth login

# 2. Docker の設定を更新
gcloud auth configure-docker asia-northeast1-docker.pkg.dev

# 3. それでもダメな場合は、認証ヘルパーを直接設定
gcloud auth print-access-token | docker login -u oauth2accesstoken --password-stdin https://asia-northeast1-docker.pkg.dev
```

### Q7: ローカル開発で Phoenix.PubSub のエラーが出ます

**A:** ローカルでは PG2 アダプターを使用します：

1. 環境変数を確認
   ```bash
   # GOOGLE_CLOUD_PROJECT を設定しない
   unset GOOGLE_CLOUD_PROJECT
   ```

2. ノード間通信を確認
   ```bash
   # iex で確認
   Node.list()
   ```

### Q8: Cloud Run のヘルスチェックが失敗します

**A:** 以下を確認：

1. **ポート設定**
   - Dockerfile で `EXPOSE 8080` または `EXPOSE 4000`
   - 環境変数 `PORT` が正しく設定されている

2. **ヘルスチェックエンドポイント**
   ```bash
   # ローカルで確認
   curl http://localhost:8080/health
   ```

3. **起動時間**
   - Cloud Run の設定で startup probe の時間を延長

### Q9: フロントエンドから GraphQL に接続できません

**A:** CORS とURLの設定を確認：

1. **client_service の CORS設定**
   - `cors_plug` が正しく設定されているか

2. **環境変数の確認**
   ```bash
   # frontend/.env.production
   NEXT_PUBLIC_GRAPHQL_ENDPOINT=https://client-service-dev-xxxxx.a.run.app/graphql
   NEXT_PUBLIC_WS_ENDPOINT=wss://client-service-dev-xxxxx.a.run.app/socket/websocket
   ```

3. **Cloud Run の公開設定**
   - client-service が「allUsers」に公開されているか確認

### Q10: 料金が心配です

**A:** 以下の方法でコストを管理：

1. **無料枠の活用**
   - Cloud Run: 月200万リクエストまで無料
   - Pub/Sub: 月10GBまで無料
   - Firebase Auth: 無制限（Google認証）

2. **最小インスタンス数を0に設定**
   ```hcl
   # terraform.tfvars
   services = {
     command-service = {
       min_scale = 0  # 使用時のみ起動
     }
   }
   ```

3. **予算アラートの設定**
   ```bash
   gcloud billing budgets create \
     --billing-account=BILLING_ACCOUNT_ID \
     --display-name="CQRS Demo Budget" \
     --budget-amount=1000JPY
   ```

### Q11: 開発環境と本番環境を分けたいです

**A:** Terraform のワークスペースを使用：

```bash
# 新しい環境を作成
cd terraform/environments
cp -r dev prod
cd prod

# terraform.tfvars を編集
environment = "prod"

# 別のワークスペースで管理
terraform workspace new prod
terraform apply
```

### Q12: ログはどこで確認できますか？

**A:** 各サービスでログの確認方法が異なります：

1. **Cloud Run のログ**
   ```bash
   gcloud run services logs read command-service-dev \
     --region=asia-northeast1 \
     --limit=100
   ```

2. **Cloud Console で確認**
   - https://console.cloud.google.com/logs
   - リソースタイプ: Cloud Run Revision

3. **構造化ログの検索**
   ```bash
   gcloud logging read "resource.type=cloud_run_revision AND severity>=ERROR" \
     --limit=50 \
     --format=json
   ```

### トラブル時の確認手順

1. **環境変数の確認**
2. **ログの確認**
3. **ヘルスチェックの確認**
4. **IAM権限の確認**
5. **ネットワーク設定の確認**

それでも解決しない場合は、Issueを作成してください。
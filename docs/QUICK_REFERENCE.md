# クイックリファレンス

## 環境変数の設定場所

### ローカル開発

```
elixir-cqrs/
├── (バックエンドは環境変数を直接使用)
└── frontend/
    ├── .env.example            # フロントエンド用テンプレート
    └── .env.local              # フロントエンド用（Next.js）
```

**注意**: Elixir/Phoenix は .env ファイルを使用しません。環境変数はシェルで直接設定するか、起動コマンドで指定します。

### 本番環境（Google Cloud）

```
elixir-cqrs/
├── (バックエンドは Cloud Run 環境変数を使用)
├── terraform/
│   └── environments/
│       └── dev/
│           └── terraform.tfvars  # Terraform変数（Git管理外）
└── frontend/
    ├── .env.example            # フロントエンド用テンプレート
    └── .env.production         # Vercelデプロイ用（Git管理外）
```

**注意**: バックエンドの環境変数は Cloud Run で自動的に設定されます。

## 必要な値の取得場所

### 1. Google Cloud Project ID
```bash
gcloud config get-value project
# または
echo $PROJECT_ID
```

### 2. Supabase の値
1. https://app.supabase.com にログイン
2. プロジェクトを選択
3. Settings → API で確認：
   - `Project URL` → `supabase_url`
   - `service_role key` → `supabase_service_key`
4. Settings → Database で確認：
   - `Connection string` → `DATABASE_URL`

### 3. Firebase の値
1. https://console.firebase.google.com にログイン
2. プロジェクトを選択
3. プロジェクト設定（歯車アイコン）→ 全般
4. 「マイアプリ」セクションで確認：
   - `apiKey` → `FIREBASE_API_KEY`
   - `authDomain` → `FIREBASE_AUTH_DOMAIN`
   - `projectId` → `FIREBASE_PROJECT_ID`

## コマンド早見表

### 初期セットアップ
```bash
# Google Cloud プロジェクト作成
gcloud projects create YOUR-PROJECT-ID --name="Your Project Name"
gcloud config set project YOUR-PROJECT-ID

# 請求アカウントをリンク
gcloud beta billing accounts list
gcloud beta billing projects link YOUR-PROJECT-ID --billing-account=BILLING-ID
```

### Terraform
```bash
cd terraform/environments/dev
terraform init      # 初期化
terraform plan      # 計画確認
terraform apply     # 実行
terraform output    # 出力確認
terraform destroy   # 削除（注意！）
```

### Docker & デプロイ
```bash
# 認証
gcloud auth configure-docker asia-northeast1-docker.pkg.dev

# ビルド & プッシュ
REGISTRY_URL=$(cd terraform/environments/dev && terraform output -raw artifact_registry_url)
docker build -f apps/command_service/Dockerfile -t $REGISTRY_URL/command-service:latest .
docker push $REGISTRY_URL/command-service:latest

# Cloud Run 更新
cd terraform/environments/dev && terraform apply -auto-approve
```

### ローカル開発
```bash
# バックエンド起動
docker compose up -d    # DB起動
mix deps.get           # 依存関係
mix ecto.setup         # DB設定

# 環境変数を設定してサーバー起動
MIX_ENV=dev PORT=4000 iex -S mix phx.server

# または環境変数をエクスポートしてから起動
export MIX_ENV=dev
export PORT=4000
iex -S mix phx.server

# フロントエンド起動
cd frontend
bun install
bun dev
```

### トラブルシューティング
```bash
# ログ確認
gcloud run services logs read command-service-dev --region=asia-northeast1 --limit=50

# Secret確認
gcloud secrets versions list supabase-url

# API有効化
gcloud services enable run.googleapis.com pubsub.googleapis.com

# ヘルスチェック
curl $(terraform output -json cloud_run_urls | jq -r '."command-service"')/health
```

## ファイル設定例

### バックエンド環境変数 (ローカル開発用)
```bash
# シェルで設定または起動時に指定
# Firebase（ローカルではダミー値でOK）
export FIREBASE_PROJECT_ID=dummy-project-id
export FIREBASE_API_KEY=dummy-api-key

# Database（Docker Compose）
export DATABASE_URL_EVENT=postgresql://postgres:postgres@localhost:5432/event_driven_playground_event_store_dev
export DATABASE_URL_COMMAND=postgresql://postgres:postgres@localhost:5433/event_driven_playground_command_dev
export DATABASE_URL_QUERY=postgresql://postgres:postgres@localhost:5434/event_driven_playground_query_dev

# その他
export MIX_ENV=dev
export PORT=4000  # Phoenix サーバーのポート
```

### frontend/.env.local (ローカル開発用)
```bash
NEXT_PUBLIC_GRAPHQL_ENDPOINT=http://localhost:4000/graphql
NEXT_PUBLIC_WS_ENDPOINT=ws://localhost:4000/socket/websocket
NEXT_PUBLIC_FIREBASE_API_KEY=dummy-api-key
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=localhost
NEXT_PUBLIC_FIREBASE_PROJECT_ID=dummy-project-id
```

### terraform.tfvars (本番用)
```hcl
project_id  = "your-gcp-project-id"
region      = "asia-northeast1"
environment = "dev"

supabase_url         = "https://xxxxx.supabase.co"
supabase_service_key = "eyJhbGci..."

firebase_config = {
  api_key     = "AIzaSy..."
  auth_domain = "your-gcp-project-id.firebaseapp.com"
  project_id  = "your-gcp-project-id"
}
```

### frontend/.env.production (Vercel用)
```bash
# Terraform output から取得
NEXT_PUBLIC_GRAPHQL_ENDPOINT=https://client-service-dev-xxxxx.a.run.app/graphql
NEXT_PUBLIC_WS_ENDPOINT=wss://client-service-dev-xxxxx.a.run.app/socket/websocket

# Firebase Console から取得
NEXT_PUBLIC_FIREBASE_API_KEY=AIzaSy...
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=your-project.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=your-project-id
```

## チェックリスト

### ローカル開発開始前
- [ ] Docker Desktop が起動している
- [ ] バックエンド用の環境変数が設定されている（シェルまたは起動スクリプト）
- [ ] `frontend/.env.local` ファイルが存在する（`cp .env.example .env.local`）
- [ ] `docker compose up -d` でDBが起動している

### 本番デプロイ前
- [ ] Google Cloud プロジェクトが作成済み
- [ ] Supabase プロジェクトが作成済み
- [ ] Firebase プロジェクトが設定済み
- [ ] `terraform.tfvars` に正しい値が設定されている
- [ ] `gcloud auth login` で認証済み
- [ ] 必要なAPIが有効化されている
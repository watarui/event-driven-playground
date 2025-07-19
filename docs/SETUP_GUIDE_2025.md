# セットアップガイド 2025

このガイドでは、ローカル開発環境と Google Cloud へのデプロイ環境の両方について、ステップバイステップで設定方法を説明します。

## 目次

1. [事前準備](#事前準備)
2. [ローカル開発環境のセットアップ](#ローカル開発環境のセットアップ)
3. [Google Cloud 環境のセットアップ](#google-cloud環境のセットアップ)
4. [デプロイ手順](#デプロイ手順)
5. [トラブルシューティング](#トラブルシューティング)

## 事前準備

### 必要なアカウント

1. **Google Cloud アカウント**

   - https://cloud.google.com にアクセス
   - 「無料で開始」をクリック
   - クレジットカード登録（無料枠あり）

2. **Supabase アカウント**

   - https://supabase.com にアクセス
   - 「Start your project」をクリック
   - GitHub アカウントでサインアップ

3. **Vercel アカウント**
   - https://vercel.com にアクセス
   - GitHub アカウントでサインアップ

### 必要なツールのインストール

```bash
# macOS の場合
# Google Cloud CLI
brew install google-cloud-sdk

# Terraform
brew install terraform

# その他必要なツール
brew install jq
brew install bun  # または npm/yarn

# gcloud の初期化
gcloud init
```

## ローカル開発環境のセットアップ

### 0. Firebase 認証の設定（初回のみ）

ローカル開発では Firebase Authentication のみを使用します。他のクラウドリソースは不要です。

```bash
# ローカル環境用の Terraform ディレクトリに移動
cd terraform/environments/local

# 設定ファイルをコピー
cp terraform.tfvars.example terraform.tfvars

# terraform.tfvars を編集して以下を設定:
# - project_id: あなたの Google Cloud プロジェクト ID
# - google_oauth_client_id: OAuth クライアント ID
# - google_oauth_client_secret: OAuth クライアントシークレット

# Terraform を初期化
terraform init

# Firebase 認証のみをセットアップ
terraform apply
```

### 1. 環境変数の設定

#### バックエンド用（環境変数）

Elixir/Phoenix は .env ファイルを使用しません。環境変数は直接シェルに設定するか、起動スクリプトで設定します：

```bash
# ローカル開発用 - シェルで直接設定
export MIX_ENV=dev
export FIREBASE_PROJECT_ID=your-project-id-local
export FIREBASE_API_KEY=dummy-api-key-for-local

# Database URLs (Docker Compose のPostgreSQL)
export DATABASE_URL_EVENT=postgresql://postgres:postgres@localhost:5432/event_driven_playground_event_store_dev
export DATABASE_URL_COMMAND=postgresql://postgres:postgres@localhost:5433/event_driven_playground_command_dev
export DATABASE_URL_QUERY=postgresql://postgres:postgres@localhost:5434/event_driven_playground_query_dev

# Service Configuration
export GRAPHQL_ENDPOINT=http://localhost:4000/graphql
export PORT=4000  # Phoenix サーバーのポート番号
```

または、起動時に環境変数を設定：

```bash
# 環境変数を設定して起動
MIX_ENV=dev PORT=4000 iex -S mix phx.server
```

#### フロントエンド用 (.env.example ファイル)

```bash
cd frontend
# ローカル開発用
cp .env.example .env.local
```

`frontend/.env.local` ファイルを編集：

```bash
# ローカル開発用
NEXT_PUBLIC_GRAPHQL_ENDPOINT=http://localhost:4000/graphql
NEXT_PUBLIC_WS_ENDPOINT=ws://localhost:4000/socket/websocket
NEXT_PUBLIC_FIREBASE_API_KEY=dummy-api-key-for-local
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=localhost
NEXT_PUBLIC_FIREBASE_PROJECT_ID=your-project-id-local

# Firebase Admin SDK (管理者権限設定用)
FIREBASE_PROJECT_ID=your-project-id-local
FIREBASE_CLIENT_EMAIL=your-service-account-email
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nyour-private-key-here\n-----END PRIVATE KEY-----"
```

### 2. ローカルでの起動

```bash
# プロジェクトルートで
# データベースとサービスを起動
docker compose up -d

# 依存関係のインストール
mix deps.get
cd frontend && bun install && cd ..

# データベースのセットアップ
mix ecto.create
mix ecto.migrate

# バックエンドサービスの起動
iex -S mix phx.server

# 別のターミナルでフロントエンドを起動
cd frontend
bun dev
```

アクセス：

- GraphQL Playground: http://localhost:4000/graphiql
- フロントエンド: http://localhost:3000 (Next.js dev server)
- モニターダッシュボード: http://localhost:4001 (docker-compose で起動時)

### 3. 認証と権限管理の設定

このプロジェクトは Firebase Authentication を使用してドメイン全体を保護し、Google アカウントでのログインを必須としています。

#### 権限の種類

- **admin**: すべての操作が可能（Query + Mutation）
- **viewer**: 閲覧のみ可能（Query のみ、Mutation 不可）

#### 管理者権限の設定方法

1. **初回ログイン**

   - http://localhost:3000 にアクセス
   - Google アカウントでログイン
   - この時点では viewer 権限

2. **管理者権限を付与**

   - Firebase Console → Authentication → Users でユーザーの UID を確認
   - 以下の API を使用して権限を設定：

   ```bash
   curl -X POST http://localhost:3000/api/admin/set-role \
     -H "Content-Type: application/json" \
     -d '{
       "uid": "取得したUID",
       "email": "your-email@example.com",
       "role": "admin"
     }'
   ```

3. **権限の確認**
   - ログアウトして再度ログイン
   - サイドバーに「Admin」バッジが表示される
   - GraphiQL で Mutation が実行可能になる

## Google Cloud 環境のセットアップ

### 1. Google Cloud プロジェクトの作成

```bash
gcloud auth login

# プロジェクトIDを決める（グローバルにユニークである必要があります）
export PROJECT_ID="my-cqrs-demo-2025"  # あなたのプロジェクトIDに変更
export REGION="asia-northeast1"        # 東京リージョン

# プロジェクトを作成
gcloud projects create $PROJECT_ID --name="CQRS Demo 2025"

# プロジェクトを選択
gcloud config set project $PROJECT_ID

# 請求アカウントを確認
gcloud beta billing accounts list
# ACCOUNT_ID をメモ

# 請求アカウントをリンク（BILLING_ACCOUNT_IDを実際のIDに置き換え）
gcloud beta billing projects link $PROJECT_ID --billing-account=BILLING_ACCOUNT_ID
```

### 2. Supabase データベースのセットアップ

1. **Supabase Dashboard にログイン**

   - https://app.supabase.com

2. **新しいプロジェクトを作成**

   - 「New project」をクリック
   - Project name: `cqrs-demo-db`
   - Database Password: 安全なパスワードを生成（メモしておく）
   - Region: `Northeast Asia (Tokyo)`
   - 「Create new project」をクリック

3. **プロジェクト設定から必要な情報を取得**

   - Settings → API → Project URL をコピー
   - Settings → API → service_role key をコピー（秘密鍵）

4. **SQL エディタでスキーマを作成**
   - SQL Editor を開く
   - 以下の SQL を実行：

```sql
-- スキーマの作成
CREATE SCHEMA IF NOT EXISTS event_store;
CREATE SCHEMA IF NOT EXISTS command;
CREATE SCHEMA IF NOT EXISTS query;

-- サービスロールに権限を付与
GRANT ALL ON SCHEMA event_store TO service_role;
GRANT ALL ON SCHEMA command TO service_role;
GRANT ALL ON SCHEMA query TO service_role;

-- 各スキーマのデフォルト権限
ALTER DEFAULT PRIVILEGES IN SCHEMA event_store GRANT ALL ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA command GRANT ALL ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA query GRANT ALL ON TABLES TO service_role;
```

### 3. Firebase プロジェクトのセットアップ

1. **Firebase Console にアクセス**

   - https://console.firebase.google.com
   - 「プロジェクトを作成」をクリック
   - 「既存の Google Cloud プロジェクトを追加」を選択
   - 先ほど作成した `$PROJECT_ID` を選択

2. **Authentication を有効化**

   - 左メニューから「Authentication」を選択
   - 「始める」をクリック
   - 「Sign-in method」タブを選択
   - 「Google」を有効化
     - プロジェクト名を入力
     - サポートメールを選択
     - 「保存」をクリック

3. **Firebase 設定を取得**

   - プロジェクト設定（歯車アイコン）→ プロジェクトの設定
   - 「全般」タブの下部「マイアプリ」セクション
   - 「</> ウェブ」アイコンをクリック
   - アプリのニックネーム: `cqrs-web`
   - 「アプリを登録」をクリック
   - 表示された設定をメモ：
     ```javascript
     const firebaseConfig = {
       apiKey: "...",
       authDomain: "...",
       projectId: "...",
       storageBucket: "...",
       messagingSenderId: "...",
       appId: "...",
     };
     ```

4. **Firebase Admin SDK の設定（権限管理用）**
   - プロジェクト設定（歯車アイコン）→ サービスアカウント
   - 「新しい秘密鍵の生成」をクリック
   - JSON ファイルがダウンロードされる
   - このファイルから以下の値を取得：
     - `project_id`
     - `client_email`
     - `private_key`
   - **重要**: この秘密鍵は安全に保管し、Git にコミットしないこと

### 4. Google OAuth クライアントの設定

Firebase Authentication で Google ログインを有効にするため、OAuth クライアントを設定します：

1. **Google Cloud Console にアクセス**

   ```bash
   # ブラウザで開く
   open https://console.cloud.google.com
   ```

2. **OAuth クライアント ID の作成**

   - メニュー → API とサービス → 認証情報
   - 「認証情報を作成」→「OAuth クライアント ID」をクリック
   - アプリケーションの種類: 「ウェブアプリケーション」を選択
   - 名前: `CQRS Demo Web App`（任意）

3. **承認済みのオリジンとリダイレクト URI の設定**

   - 承認済みの JavaScript 生成元:
     ```
     http://localhost:3000
     https://your-app.vercel.app
     ```
   - 承認済みのリダイレクト URI:
     ```
     http://localhost:3000/api/auth/callback/google
     ```

4. **クライアント ID とシークレットを保存**
   - 作成後に表示される値をメモ
   - **重要**: クライアントシークレットは作成時にのみ表示されます

### 5. Terraform 設定ファイルの作成

```bash
# terraform/environments/dev ディレクトリに移動
cd terraform/environments/dev

# terraform.tfvars.example をコピーして編集
cp terraform.tfvars.example terraform.tfvars

# 設定ファイルを編集
# あなたの値に置き換えてください
cat > terraform.tfvars <<EOF
project_id  = "${PROJECT_ID}"
region      = "${REGION}"
environment = "dev"

# Supabase configuration
# 注意: Cloud Run デプロイ時にDATABASE_URLとして使用されます
# ローカル開発では不要なので、Supabaseプロジェクトがない場合はプレースホルダーのままでOK
supabase_url         = "https://xxxxx.supabase.co"
supabase_service_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

# Firebase configuration (Firebaseコンソールから取得した値)
firebase_config = {
  api_key     = "AIzaSy..."
  auth_domain = "${PROJECT_ID}.firebaseapp.com"
  project_id  = "${PROJECT_ID}"
}

# Google OAuth configuration (上記手順4で取得した値)
google_oauth_client_id     = "xxxxx.apps.googleusercontent.com"
google_oauth_client_secret = "GOCSPX-xxxxx"

enable_monitoring = true
EOF

# .gitignore に追加されていることを確認（terraform.tfvarsは公開しない）
cat ../../.gitignore | grep terraform.tfvars
```

### 6. Terraform でインフラを構築

```bash
# terraform ディレクトリに移動（environments/dev ではなくルート）
cd ../../  # /Users/w/w/elixir-cqrs/terraform に移動

# Terraform を初期化
terraform init

# Google Cloud の認証設定（初回のみ）
# ブラウザが開いてGoogleアカウントでのログインを求められます
gcloud auth application-default login

# 何が作成されるか確認（dev環境の変数ファイルを指定）
terraform plan -var-file=environments/dev/terraform.tfvars

# インフラを構築（yesと入力）
terraform apply -var-file=environments/dev/terraform.tfvars
```

### 7. 環境変数の設定（本番用）

#### バックエンド用（環境変数）

本番環境では、Cloud Run が自動的に環境変数を設定します。Terraform と Secret Manager を通じて管理されるため、手動での .env ファイル作成は不要です。

参考として、以下の環境変数が Cloud Run で設定されます：

```bash
# 本番環境用（Cloud Run で自動設定）
MIX_ENV=prod
NODE_ENV=production

# Terraformの出力から取得
GOOGLE_CLOUD_PROJECT=${PROJECT_ID}

# SupabaseのダッシュボードのSettings → Database から取得
DATABASE_URL=postgresql://postgres.[project-ref]:[password]@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres

# Firebaseコンソールから取得
FIREBASE_PROJECT_ID=${PROJECT_ID}
FIREBASE_API_KEY=AIzaSy...

# Secret Managerで管理される
# SUPABASE_SERVICE_KEY=...
```

#### フロントエンド用 (.env.production)

```bash
cd frontend
# 本番環境用
cp .env.example .env.production
```

`frontend/.env.production` を編集：

```bash
# Terraformの出力から取得（terraform output で確認）
NEXT_PUBLIC_GRAPHQL_ENDPOINT=https://client-service-dev-xxxxx.a.run.app/graphql
NEXT_PUBLIC_WS_ENDPOINT=wss://client-service-dev-xxxxx.a.run.app/socket/websocket

# Firebaseコンソールから取得した値
NEXT_PUBLIC_FIREBASE_API_KEY=AIzaSy...
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=${PROJECT_ID}.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=${PROJECT_ID}
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=${PROJECT_ID}.appspot.com
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=123456789
NEXT_PUBLIC_FIREBASE_APP_ID=1:123456789:web:xxxxx
```

## デプロイ手順

### 1. Docker イメージのビルドとプッシュ

```bash
# プロジェクトルートで実行
cd /Users/w/w/elixir-cqrs

# Artifact Registry に認証
gcloud auth configure-docker ${REGION}-docker.pkg.dev

# Terraform の出力から Registry URL を取得
cd terraform/environments/dev
export REGISTRY_URL=$(terraform output -raw artifact_registry_url)
cd ../../..

# 各サービスのイメージをビルド
for service in command-service query-service client-service; do
  echo "Building $service..."
  docker build -f apps/${service//-/_}/Dockerfile -t $REGISTRY_URL/$service:latest .
  docker push $REGISTRY_URL/$service:latest
done
```

### 2. Cloud Run へのデプロイ

```bash
# terraform ディレクトリに移動
cd /Users/w/w/elixir-cqrs/terraform

# 最新のイメージでサービスを更新（dev環境の変数を使用）
terraform apply -var-file=environments/dev/terraform.tfvars -auto-approve
```

### 3. フロントエンドのデプロイ（Vercel）

```bash
cd frontend

# Vercel CLI をインストール（初回のみ）
npm i -g vercel

# Vercel にログイン
vercel login

# デプロイ
vercel --prod

# 環境変数を設定するよう求められたら、.env.production の値を使用
```

## 動作確認

### 1. サービスの URL を確認

```bash
cd terraform/environments/dev

# Cloud Run サービスの URL を表示
terraform output cloud_run_urls
```

### 2. ヘルスチェック

```bash
# 各サービスのヘルスチェック
COMMAND_URL=$(terraform output -json cloud_run_urls | jq -r '."command-service"')
QUERY_URL=$(terraform output -json cloud_run_urls | jq -r '."query-service"')
CLIENT_URL=$(terraform output -json cloud_run_urls | jq -r '."client-service"')

curl $COMMAND_URL/health
curl $QUERY_URL/health
curl $CLIENT_URL/health
```

### 3. GraphQL Playground

ブラウザで Client Service の URL にアクセス：

```
https://client-service-dev-xxxxx.a.run.app/graphiql
```

## 環境変数まとめ

### ローカル開発環境

| ファイル/設定 | 場所                  | 用途                             |
| ------------- | --------------------- | -------------------------------- |
| 環境変数      | シェル/起動スクリプト | バックエンド用（Elixir/Phoenix） |
| `.env.local`  | frontend/             | フロントエンド用（Next.js）      |

### 本番環境（Google Cloud）

| ファイル/設定      | 場所                        | 用途                             |
| ------------------ | --------------------------- | -------------------------------- |
| `terraform.tfvars` | terraform/environments/dev/ | Terraform の変数（秘密情報含む） |
| Cloud Run 環境変数 | Google Cloud                | バックエンド用（自動設定）       |
| `.env.production`  | frontend/                   | Vercel デプロイ時の環境変数      |

### 重要な環境変数

| 変数名                    | 取得元                                   | 用途                       |
| ------------------------- | ---------------------------------------- | -------------------------- |
| `PROJECT_ID`              | Google Cloud Console                     | GCP プロジェクト ID        |
| `supabase_url`            | Supabase Dashboard → Settings → API      | データベース接続 URL       |
| `supabase_service_key`    | Supabase Dashboard → Settings → API      | サービスロールキー（秘密） |
| `firebase_config.api_key` | Firebase Console → プロジェクト設定      | Firebase API キー          |
| `DATABASE_URL`            | Supabase Dashboard → Settings → Database | PostgreSQL 接続文字列      |

## トラブルシューティング

### よくある問題

1. **Terraform apply でエラーが出る**

   認証エラーの場合：

   ```bash
   # Google Cloud の認証を設定
   gcloud auth application-default login
   ```

   API が有効化されていない場合：

   ```bash
   # APIを有効化
   gcloud services enable run.googleapis.com
   gcloud services enable pubsub.googleapis.com
   gcloud services enable secretmanager.googleapis.com
   gcloud services enable artifactregistry.googleapis.com
   ```

2. **Docker push で認証エラー**

   ```bash
   # 再認証
   gcloud auth login
   gcloud auth configure-docker ${REGION}-docker.pkg.dev
   ```

3. **Cloud Run でデータベース接続エラー**

   - Supabase の接続文字列が正しいか確認
   - Secret Manager に正しい値が設定されているか確認

   ```bash
   gcloud secrets versions list supabase-url
   ```

4. **フロントエンドで GraphQL エラー**
   - CORS の設定を確認
   - Cloud Run の URL が正しいか確認

### ログの確認方法

```bash
# Cloud Run のログ
gcloud run services logs read command-service-dev --region=$REGION --limit=50

# Pub/Sub のメトリクス
gcloud monitoring metrics-descriptors list --filter="metric.type:pubsub"
```

### コストの確認

```bash
# 現在の請求額を確認
gcloud billing accounts list
gcloud beta billing budgets list
```

## 次のステップ

1. **本番環境の構築**

   - `terraform/environments/prod` に本番用の設定を作成
   - より厳格なセキュリティ設定

2. **CI/CD パイプラインの設定**

   - GitHub Actions の設定
   - 自動デプロイの構築

3. **監視とアラートの設定**

   - Cloud Monitoring のダッシュボード作成
   - アラートポリシーの設定

4. **カスタムドメインの設定**
   - Cloud Run にカスタムドメインを設定
   - SSL 証明書の設定

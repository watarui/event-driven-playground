# 環境変数設定ガイド

このドキュメントでは、elixir-cqrs プロジェクトで使用する環境変数について説明します。

## 概要

本プロジェクトは環境変数を使用して設定を管理しています。これにより、環境ごとに異なる設定を安全に管理できます。

**重要**: 
- **バックエンド (Elixir/Phoenix)**: .env ファイルを使用しません。環境変数はシェルで直接設定するか、デプロイサービスで設定します。
- **フロントエンド (Next.js/Bun)**: .env ファイルを使用します。Bun が自動的に読み込みます。

## 環境変数の設定方法

### 開発環境

#### バックエンド
```bash
# シェルで直接設定
export MIX_ENV=dev
export PORT=4000
export DATABASE_URL_EVENT=postgresql://postgres:postgres@localhost:5432/event_driven_playground_event_store_dev
# ... その他の環境変数

# または起動時に指定
MIX_ENV=dev PORT=4000 iex -S mix phx.server
```

#### フロントエンド
```bash
cd frontend
cp .env.example .env.local
vi .env.local  # 必要に応じて編集
```

### 本番環境

本番環境では、以下の方法で環境変数を管理します：

#### バックエンド
```bash
# Cloud Run が自動的に環境変数を設定
# Terraform と Secret Manager を通じて管理
# 手動での .env ファイル作成は不要
```

#### フロントエンド
```bash
cd frontend
cp .env.example .env.production
vi .env.production  # 本番用の値を設定
```

#### インフラ構築時（Terraform）
```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars  # 実際の値を設定
```

#### 実行時
- **Google Cloud Secret Manager** - 機密情報
- **Cloud Run 環境変数** - 一般設定
- **Vercel 環境変数** - フロントエンド設定

## 環境変数一覧

### 共通設定

| 変数名 | 説明 | デフォルト値 | 必須 |
| ------ | ---- | ----------- | ---- |
| `MIX_ENV` | Elixir 環境 | dev | ○ |
| `NODE_ENV` | Node.js 環境 | development | ○ |
| `FIREBASE_PROJECT_ID` | Firebase プロジェクトID | - | 本番環境 |
| `FIREBASE_API_KEY` | Firebase API キー | - | 本番環境 |
| `GOOGLE_CLOUD_PROJECT` | GCP プロジェクトID | - | 本番環境 |

### データベース設定

#### Event Store

| 変数名                     | 説明                   | デフォルト値                | 必須     |
| -------------------------- | ---------------------- | --------------------------- | -------- |
| `EVENT_STORE_HOST`         | ホスト名               | localhost                   | 開発環境 |
| `EVENT_STORE_PORT`         | ポート番号             | 5432                        | 開発環境 |
| `EVENT_STORE_DATABASE`     | データベース名         | event_driven_playground_event_store_dev | 開発環境 |
| `EVENT_STORE_USER`         | ユーザー名             | postgres                    | 開発環境 |
| `EVENT_STORE_PASSWORD`     | パスワード             | postgres                    | 開発環境 |
| `EVENT_STORE_DATABASE_URL` | 接続 URL（本番環境用） | -                           | 本番環境 |

#### Command Service

| 変数名                 | 説明                   | デフォルト値            | 必須     |
| ---------------------- | ---------------------- | ----------------------- | -------- |
| `COMMAND_DB_HOST`      | ホスト名               | localhost               | 開発環境 |
| `COMMAND_DB_PORT`      | ポート番号             | 5433                    | 開発環境 |
| `COMMAND_DATABASE`     | データベース名         | event_driven_playground_command_dev | 開発環境 |
| `COMMAND_DB_USER`      | ユーザー名             | postgres                | 開発環境 |
| `COMMAND_DB_PASSWORD`  | パスワード             | postgres                | 開発環境 |
| `COMMAND_DATABASE_URL` | 接続 URL（本番環境用） | -                       | 本番環境 |

#### Query Service

| 変数名               | 説明                   | デフォルト値          | 必須     |
| -------------------- | ---------------------- | --------------------- | -------- |
| `QUERY_DB_HOST`      | ホスト名               | localhost             | 開発環境 |
| `QUERY_DB_PORT`      | ポート番号             | 5434                  | 開発環境 |
| `QUERY_DATABASE`     | データベース名         | event_driven_playground_query_dev | 開発環境 |
| `QUERY_DB_USER`      | ユーザー名             | postgres              | 開発環境 |
| `QUERY_DB_PASSWORD`  | パスワード             | postgres              | 開発環境 |
| `QUERY_DATABASE_URL` | 接続 URL（本番環境用） | -                     | 本番環境 |

### アプリケーション設定

| 変数名            | 説明                          | デフォルト値 | 必須     |
| ----------------- | ----------------------------- | ------------ | -------- |
| `MIX_ENV`         | Elixir 環境                   | dev          | ○        |
| `PORT`            | HTTP ポート                   | 4000         | ○        |
| `PHX_HOST`        | Phoenix ホスト名              | localhost    | ○        |
| `SECRET_KEY_BASE` | セッションキー（64 文字以上） | -            | 本番環境 |
| `ENCRYPTION_KEY`  | 暗号化キー                    | -            | △        |

### 分散システム設定

| 変数名        | 説明            | デフォルト値       | 必須 |
| ------------- | --------------- | ------------------ | ---- |
| `NODE_NAME`   | Erlang ノード名 | client@127.0.0.1   | △    |
| `NODE_COOKIE` | Erlang クッキー | event_driven_playground_secret | △    |

### 監視・オブザーバビリティ

| 変数名                        | 説明                         | デフォルト値                       | 必須 |
| ----------------------------- | ---------------------------- | ---------------------------------- | ---- |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | OpenTelemetry エンドポイント | http://localhost:4318              | △    |
| `OTEL_SERVICE_NAME`           | サービス名                   | elixir-cqrs                        | △    |
| `OTEL_RESOURCE_ATTRIBUTES`    | リソース属性                 | deployment.environment=development | △    |

### フロントエンド設定

| 変数名 | 説明 | ローカル | 本番 |
| ------ | ---- | -------- | ---- |
| `NEXT_PUBLIC_GRAPHQL_ENDPOINT` | GraphQL エンドポイント | http://localhost:4000/graphql | Cloud Run URL |
| `NEXT_PUBLIC_WS_ENDPOINT` | WebSocket エンドポイント | ws://localhost:4000/socket/websocket | wss://cloud-run-url/socket/websocket |
| `NEXT_PUBLIC_FIREBASE_API_KEY` | Firebase API キー | dummy-api-key | 実際の値 |
| `NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN` | Firebase 認証ドメイン | localhost | {project-id}.firebaseapp.com |
| `NEXT_PUBLIC_FIREBASE_PROJECT_ID` | Firebase プロジェクトID | local-dev-project | 実際のID |

### その他の設定

| 変数名       | 説明                 | デフォルト値 | 必須 |
| ------------ | -------------------- | ------------ | ---- |
| `POOL_SIZE`  | DB 接続プールサイズ  | 10           | △    |
| `LOG_LEVEL`  | ログレベル           | debug        | △    |
| `PHX_SERVER` | Phoenix サーバー起動 | true         | △    |

## 環境ごとのファイル構成

### ファイル一覧

| 環境 | ファイル/設定 | 場所 | Git管理 | 用途 |
| ---- | ------- | ---- | ------- | ---- |
| テンプレート | `.env.example` | `/frontend/` | ✅ | フロントエンド設定テンプレート |
| ローカル | 環境変数 | シェル/起動コマンド | ❌ | バックエンド開発 |
| ローカル | `.env.local` | `/frontend/` | ❌ | フロントエンド開発 |
| 本番 | Cloud Run 環境変数 | Google Cloud | ❌ | バックエンド本番 |
| 本番 | `.env.production` | `/frontend/` | ❌ | フロントエンド本番（Vercelデプロイ） |
| 本番 | `terraform.tfvars` | `/terraform/environments/dev/` | ❌ | インフラ構築 |
| サンプル | `terraform.tfvars.example` | `/terraform/environments/dev/` | ✅ | Terraform設定例 |

### 設定の優先順位

1. **ローカル開発**
   - シェルで設定した環境変数が優先
   - 未設定の場合は `config/*.exs` のデフォルト値

2. **本番環境（Cloud Run）**
   - Secret Manager の値が最優先
   - 次に Cloud Run の環境変数
   - 最後に Docker イメージ内の設定

## セキュリティのベストプラクティス

### 1. シークレットの生成

```bash
# SECRET_KEY_BASE の生成
mix phx.gen.secret

# ランダムなパスワードの生成
openssl rand -base64 32
```

### 2. 本番環境での管理

- 環境変数を直接コミットしない
- フロントエンドの `.env.local`、`.env.production` ファイルを `.gitignore` に追加
- シークレット管理サービスを使用

### 3. Kubernetes での使用例

```bash
# シークレットの作成
kubectl create secret generic elixir-cqrs-secrets \
  --from-env-file=.env.production \
  -n elixir-cqrs
```

### 4. Docker Compose での使用例

```yaml
services:
  app:
    environment:
      - MIX_ENV=prod
      - DATABASE_URL_EVENT=postgresql://postgres:postgres@db:5432/event_store
      # その他の環境変数
```

## トラブルシューティング

### 環境変数が読み込まれない場合

1. 環境変数が正しく設定されているか確認

```bash
echo $EVENT_STORE_DATABASE_URL
```

2. runtime.exs が正しく読み込まれているか確認

```bash
mix run -e "IO.inspect(Application.get_env(:shared, Shared.Infrastructure.EventStore.Repo))"
```

環境変数やデータベース接続の詳細なトラブルシューティングについては [TROUBLESHOOTING.md](TROUBLESHOOTING.md#データベース関連) を参照してください。

## 環境別の設定例

### 開発環境 (シェル環境変数)

```bash
export MIX_ENV=dev
export EVENT_STORE_HOST=localhost
export EVENT_STORE_PORT=5432
export LOG_LEVEL=debug
```

### ステージング環境 (デプロイ時に設定)

```bash
MIX_ENV=prod \
EVENT_STORE_DATABASE_URL=ecto://user:pass@staging-db:5432/event_store \
LOG_LEVEL=info \
SECRET_KEY_BASE=<64文字以上のランダム文字列> \
./app start
```

### 本番環境 (Cloud Run 環境変数)

```bash
# Cloud Run が自動的に設定
MIX_ENV=prod
EVENT_STORE_DATABASE_URL=${DATABASE_URL}
LOG_LEVEL=warn
SECRET_KEY_BASE=${SECRET_KEY_BASE}
OTEL_EXPORTER_OTLP_ENDPOINT=https://otel-collector.example.com:4318
```

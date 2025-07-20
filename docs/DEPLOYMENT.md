# デプロイメントガイド

## 概要

このドキュメントでは、Event Driven Playground アプリケーションを本番環境にデプロイする方法を説明します。

## デプロイメントオプション

### 1. Google Cloud Run（推奨）

本番環境では Google Cloud Run を使用してサーバーレスでデプロイします。詳細は [PRODUCTION_DEPLOYMENT_GUIDE.md](./PRODUCTION_DEPLOYMENT_GUIDE.md) を参照してください。

### 2. Docker Compose（開発環境）

開発環境でのローカル実行用：

```bash
# 開発環境の起動
docker compose up -d
```

### 3. Elixir Release（ローカルテスト）

Elixir の組み込みリリース機能を使用したローカルテスト：

```bash
# リリースビルド
MIX_ENV=prod mix deps.get
MIX_ENV=prod mix compile
MIX_ENV=prod mix release

# 起動
_build/prod/rel/event_driven_playground/bin/event_driven_playground start
```

## 環境変数

### 必須の環境変数

```bash
# データベース接続
DATABASE_URL_EVENT=postgresql://user:pass@host:5432/event_store
DATABASE_URL_COMMAND=postgresql://user:pass@host:5433/command_db
DATABASE_URL_QUERY=postgresql://user:pass@host:5434/query_db

# Phoenix 設定
SECRET_KEY_BASE=your-64-character-secret-key
PHX_HOST=your-domain.com
PHX_PORT=4000

# 監視（オプション）
OTEL_EXPORTER_OTLP_ENDPOINT=http://your-otel-collector:4317
```

## データベースの準備

### 1. PostgreSQL のセットアップ

```sql
-- イベントストア用
CREATE DATABASE event_store;

-- コマンドサービス用
CREATE DATABASE command_db;

-- クエリサービス用
CREATE DATABASE query_db;
```

### 2. マイグレーションの実行

```bash
# 各サービスでマイグレーションを実行
MIX_ENV=prod mix ecto.migrate
```

## セキュリティ設定

### SSL/TLS の設定

```elixir
# config/prod.exs
config :client_service, ClientServiceWeb.Endpoint,
  url: [scheme: "https", host: "your-domain.com", port: 443],
  force_ssl: [rewrite_on: [:x_forwarded_proto]]
```

### ファイアウォール設定

```bash
# 必要なポートのみ開放
ufw allow 80/tcp   # HTTP
ufw allow 443/tcp  # HTTPS
ufw allow 22/tcp   # SSH（管理用）
```

## 監視とログ

### ヘルスチェック

各サービスは `/health` エンドポイントを提供します：

```bash
curl http://localhost:4000/health
```

### ログの設定

```elixir
# config/prod.exs
config :logger,
  level: :info,
  backends: [:console, {LoggerFileBackend, :file_log}]

config :logger, :file_log,
  path: "/var/log/event_driven_playground/app.log",
  level: :info
```

## バックアップ

### イベントストアのバックアップ

```bash
# 日次バックアップスクリプト
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
pg_dump $DATABASE_URL_EVENT > /backup/event_store_$DATE.sql

# 古いバックアップの削除（30日以上）
find /backup -name "event_store_*.sql" -mtime +30 -delete
```

## スケーリング

### 読み取りの水平スケーリング

Query Service は複数インスタンスを起動可能：

```bash
# インスタンス 1
PORT=4001 elixir --name query1@host -S mix run --no-halt

# インスタンス 2
PORT=4002 elixir --name query2@host -S mix run --no-halt
```

### データベースのスケーリング

- **イベントストア**: 書き込みが多いため、高速な SSD を推奨
- **クエリ DB**: 読み取り専用レプリカの追加を検討
- **接続プーリング**: PgBouncer の使用を推奨

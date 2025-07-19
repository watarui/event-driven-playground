## 前提条件

- **Elixir** 1.18 以上
- **Erlang/OTP** 27 以上
- **Docker** & Docker Compose
- **PostgreSQL** クライアント（`psql`、`pg_isready`）
- **Bun** 1.0 以上

## Quick Start

### 1. Docker の起動

```bash
# PostgreSQL、Jaeger、Grafana などのインフラを起動
docker compose up -d
```

### 2. 初回セットアップ

```bash
# 依存関係のインストールとデータベースのセットアップ
./scripts/setup.sh
```

### 3. フロントエンドのセットアップ

```bash
# Frontend の依存関係をインストール
cd frontend
bun install

# 環境変数ファイルの準備
cp .env.example .env.local
# .env.local を編集して Firebase の認証情報を設定
```

### 4. サービス起動

```bash
# バックエンドのみ（別ターミナルで Frontend を起動する場合）
./scripts/start.sh

# フロントエンドも含めて起動
./scripts/start.sh --frontend
```

別ターミナルでフロントエンドを起動する場合：
```bash
cd frontend
bun run dev
```

### 5. シードデータ投入（オプション）

```bash
./scripts/seed.sh
```

## 推奨：開発環境の一括起動

開発に必要なすべて（バックエンド、フロントエンド、シードデータ）を一度に起動：

```bash
./scripts/dev.sh -f -s
```

これにより以下が実行されます：
- Docker コンテナの起動
- データベースのセットアップ
- Elixir サービスの起動
- フロントエンド（Monitor Dashboard）の起動
- サンプルデータの投入

> **注意**: フロントエンドは Docker ではなくローカルで実行されます。これによりホットリロードが高速に動作し、開発効率が向上します。

## 主要なスクリプト

| スクリプト | 説明 | オプション |
|-----------|------|-----------|
| `setup.sh` | 初回セットアップ（Docker起動、DB作成、マイグレーション） | なし |
| `start.sh` | サービス起動 | `--frontend` |
| `stop.sh` | サービス停止 | `--all` (Dockerも停止) |
| `reset.sh` | 完全リセット（データ削除して再セットアップ） | なし |
| `dev.sh` | 開発用統合コマンド | `-f`, `-s`, `-r` |
| `seed.sh` | シードデータ投入 | なし |
| `logs.sh` | ログ表示 | サービス名, `-n` |

## サービスのアクセス URL

- **GraphQL API**: http://localhost:4000/graphql
- **GraphiQL (開発用UI)**: http://localhost:4000/graphiql
- **Monitor Dashboard**: http://localhost:3000
- **Jaeger UI**: http://localhost:16686
- **Grafana**: http://localhost:3001 (admin/admin)
- **Prometheus**: http://localhost:9090
- **pgweb (Event)**: http://localhost:5050
- **pgweb (Command)**: http://localhost:5051
- **pgweb (Query)**: http://localhost:5052

## 権限管理

このシステムは Firebase Authentication のカスタムクレームを使用した権限管理システムを実装しています。

### 権限の種類

- **admin**: 全権限（ユーザー管理、システム設定変更）
- **writer**: 書き込み権限（データの作成・更新）
- **viewer**: 読み取り専用（デフォルト）

### 初期管理者の設定

#### 開発環境
- **自動設定**: システムに管理者が存在しない場合、最初にログインしたユーザーが管理者になれます
- **環境変数設定（任意）**: `INITIAL_ADMIN_EMAIL` を設定することで、特定のメールアドレスのみを初期管理者に制限できます

```bash
# frontend/.env.local
INITIAL_ADMIN_EMAIL=dev@example.com  # 任意
```

#### 本番環境
- **環境変数設定（必須）**: セキュリティのため、`INITIAL_ADMIN_EMAIL` の設定が必要です

```bash
# frontend/.env.production
INITIAL_ADMIN_EMAIL=admin@your-company.com  # 必須
```

### 管理者機能

管理者は Monitor Dashboard から以下の操作が可能です：
- ユーザー一覧の表示
- ユーザーの権限変更（admin/writer/viewer）
- システム設定の変更

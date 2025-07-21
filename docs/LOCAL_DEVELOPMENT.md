# ローカル開発環境ガイド

## 概要

Event Driven Playground のローカル開発環境は、Firestore エミュレータと Elixir サービスで構成されています。

## システム構成

```
┌─────────────────────────────────────────────────────────┐
│                    Frontend (Next.js)                    │
│                     http://localhost:3000                │
└─────────────────────────┬───────────────────────────────┘
                          │
┌─────────────────────────┴───────────────────────────────┐
│                   GraphQL API (Phoenix)                  │
│                   http://localhost:4000                  │
└──────────┬──────────────────────────────┬───────────────┘
           │                              │
┌──────────┴──────────┐        ┌─────────┴──────────┐
│   Command Service   │        │   Query Service    │
│ http://localhost:4081│        │http://localhost:4082│
└─────────────────────┘        └────────────────────┘
           │                              │
           └──────────────┬───────────────┘
                          │
                ┌─────────┴─────────┐
                │ Firestore Emulator│
                │ http://localhost:8090│
                └───────────────────┘
```

## セットアップ手順

### 1. 前提条件の確認

```bash
# Elixir のバージョン確認（1.18 以上）
elixir --version

# Docker の起動確認
docker info

# Bun のバージョン確認（1.0 以上）
bun --version
```

### 2. 初回セットアップ

```bash
# リポジトリのクローン
git clone <repository-url>
cd event-driven-playground

# 初回セットアップ（Docker 起動、依存関係インストール）
./scripts/setup.sh

# フロントエンドのセットアップ
cd frontend
bun install
cp .env.local.example .env.local
# .env.local を編集して Firebase の設定を追加
```

### 3. 開発サーバーの起動

#### オプション 1: すべてを一度に起動（推奨）

```bash
make start
```

これにより以下が実行されます：
- Docker コンテナ（Firestore エミュレータ）の起動
- バックエンドサービスの起動
- フロントエンドの起動
- シードデータの投入（初回のみ）

#### オプション 2: 個別に起動

```bash
# バックエンドのみ
./scripts/start.sh

# 別ターミナルでフロントエンド
cd frontend
bun run dev
```

## 便利なコマンド

### サービス管理

```bash
# サービスの状態確認
make status

# ログの確認
./scripts/logs.sh
# または特定のサービスのログ
./scripts/logs.sh command

# サービスの停止
make stop

# 完全リセット（データも削除）
make reset
```

### データ管理

```bash
# シードデータの投入
./scripts/seed.sh

# Firestore エミュレータのデータを確認
# ブラウザで http://localhost:8090 にアクセス
```

### 開発作業

```bash
# バックエンドのコード変更は自動リロード
# フロントエンドも同様にホットリロード対応

# テストの実行
mix test

# コードフォーマット
mix format

# 静的解析
mix credo
```

## トラブルシューティング

### ポートが使用中

```bash
# ポートの使用状況を確認
make status

# プロセスを強制終了
./scripts/stop.sh --all
```

### Firestore エミュレータの問題

```bash
# ログを確認
docker compose logs firestore

# エミュレータを再起動
docker compose restart firestore
```

### 依存関係の問題

```bash
# Elixir の依存関係を再インストール
mix deps.clean --all
mix deps.get

# フロントエンドの依存関係を再インストール
cd frontend
rm -rf node_modules
bun install
```

## 開発のヒント

### 1. エディタ設定

- VS Code の場合、ElixirLS 拡張機能をインストール
- `.formatter.exs` に従ってコードフォーマットが自動適用されます

### 2. デバッグ

```elixir
# コード内でデバッグ
require IEx
IEx.pry()
```

### 3. GraphQL の確認

- GraphiQL: http://localhost:4000/graphiql
- クエリやミューテーションをインタラクティブにテスト可能

### 4. パフォーマンス

- Firestore エミュレータはメモリ内で動作するため高速
- 本番環境とは異なるパフォーマンス特性があることに注意

## 次のステップ

- [Firestore セットアップガイド](./FIRESTORE_SETUP.md) - Firestore の詳細設定
- [アーキテクチャガイド](./ARCHITECTURE.md) - システム設計の理解
- [API ドキュメント](./API.md) - GraphQL API の仕様
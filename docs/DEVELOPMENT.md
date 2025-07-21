# 開発ガイド

## 開発環境のセットアップ

### 前提条件

以下のツールがインストールされている必要があります：

- **Elixir** 1.18 以上
- **Erlang/OTP** 28 以上
- **Node.js** 20 以上
- **bun** 1.0 以上
- **Docker** & Docker Compose
- **Google Cloud SDK** (gcloud コマンド)

### 初回セットアップ

```bash
# リポジトリのクローン
git clone https://github.com/your-org/event-driven-playground.git
cd event-driven-playground

# 依存関係のインストールとセットアップ
make setup

# 環境変数の設定（フロントエンド用）
cd frontend
cp .env.local.example .env.local
# .env.local を編集して Firebase の設定を追加
```

### サービスの起動

```bash
# バックエンドサービスのみ起動
make start

# フロントエンドも含めて起動
make start-with-frontend

# 初回起動時にサンプルデータを投入
make start-with-frontend-and-seed
```

起動後、以下のURLでアクセスできます：

- **GraphQL API**: http://localhost:4000/graphql
- **GraphiQL** (開発用UI): http://localhost:4000/graphiql
- **フロントエンド**: http://localhost:3000

## プロジェクト構造

```
apps/
├── client_service/      # GraphQL API
│   ├── lib/
│   │   ├── client_service_web/  # Phoenix Web層
│   │   │   ├── schema/          # GraphQL スキーマ定義
│   │   │   ├── resolvers/       # GraphQL リゾルバー
│   │   │   └── plugs/           # 認証などのミドルウェア
│   │   └── client_service/      # ビジネスロジック
│   └── test/
├── command_service/     # コマンド処理
│   ├── lib/
│   │   └── command_service/
│   │       ├── aggregates/      # アグリゲート
│   │       ├── commands/        # コマンドハンドラー
│   │       └── infrastructure/  # リポジトリ実装
│   └── test/
├── query_service/       # クエリ処理
│   ├── lib/
│   │   └── query_service/
│   │       ├── projections/     # イベントハンドラー
│   │       ├── queries/         # クエリハンドラー
│   │       └── infrastructure/  # リポジトリ実装
│   └── test/
└── shared/             # 共通ライブラリ
    ├── lib/
    │   └── shared/
    │       ├── domain/          # ドメインモデル
    │       ├── value_objects/   # 値オブジェクト
    │       └── infrastructure/  # 共通インフラ
    └── test/
```

## 開発フロー

### 1. 新機能の追加

新しい機能を追加する場合の一般的な流れ：

1. **ドメインイベントの定義** (`apps/shared/lib/shared/domain/events/`)
2. **コマンドの実装** (`apps/command_service/lib/command_service/commands/`)
3. **アグリゲートの更新** (`apps/command_service/lib/command_service/aggregates/`)
4. **イベントハンドラーの実装** (`apps/query_service/lib/query_service/projections/`)
5. **GraphQL スキーマの更新** (`apps/client_service/lib/client_service_web/schema/`)
6. **リゾルバーの実装** (`apps/client_service/lib/client_service_web/resolvers/`)

### 2. テストの実行

```bash
# 全てのテストを実行
make test

# 特定のアプリケーションのテストのみ
cd apps/command_service && mix test

# 特定のテストファイルのみ
mix test test/command_service/commands/create_product_test.exs
```

### 3. コードの品質チェック

```bash
# フォーマットチェック
mix format --check-formatted

# 静的解析
mix credo

# 型チェック
mix dialyzer
```

## ローカル開発のTips

### Firestore エミュレータ

ローカル環境では Firestore エミュレータを使用します：

```bash
# エミュレータの状態確認
docker compose ps

# データの確認（エミュレータUI）
open http://localhost:8090
```

### ログの確認

```bash
# 全サービスのログを表示
make logs

# 特定のサービスのログのみ
./scripts/logs.sh command

# リアルタイムでログを追跡
./scripts/logs.sh -f
```

### データのリセット

```bash
# Firestore のデータをクリア
make reset

# クリア後にシードデータを投入
make seed
```

### 環境変数

開発環境では以下の環境変数が自動的に設定されます：

- `FIRESTORE_EMULATOR_HOST=localhost:8090`
- `DATABASE_ADAPTER=firestore`
- `MIX_ENV=dev`

## トラブルシューティング

### ポートが既に使用されている

```bash
# 使用中のポートを確認
lsof -i :4000

# プロセスを停止
kill -9 <PID>
```

### Docker コンテナが起動しない

```bash
# コンテナを完全に削除して再起動
docker compose down -v
docker compose up -d
```

### 依存関係のエラー

```bash
# 依存関係をクリーンインストール
rm -rf deps _build
mix deps.get
mix compile
```

## 開発用コマンド一覧

```bash
make help              # 利用可能なコマンドを表示
make start             # サービスを起動
make stop              # サービスを停止
make restart           # サービスを再起動
make test              # テストを実行
make logs              # ログを表示
make reset             # データをリセット
make seed              # シードデータを投入
make status            # サービスの状態を確認
make clean             # ビルドアーティファクトを削除
```
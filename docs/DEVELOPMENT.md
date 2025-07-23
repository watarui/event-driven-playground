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
# 全サービスを起動（フロントエンド含む、初回はシードデータも投入）
make start

# バックエンドサービスのみ起動
make backend
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
│   │       └── infrastructure/  # Remote Bus 実装
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
│   │       └── infrastructure/  # Projection Manager
│   └── test/
└── shared/             # 共通ライブラリ
    ├── lib/
    │   └── shared/
    │       ├── domain/          # ドメインモデル
    │       ├── value_objects/   # 値オブジェクト
    │       └── infrastructure/  # 共通インフラ
    │           └── saga/        # Saga Executor
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
7. **Saga の定義**（必要な場合）(`apps/shared/lib/shared/domain/sagas/`)

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

# フロントエンドのフォーマット
cd frontend && bun run biome:format
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
- `PHX_SERVER=true`
- `PORT=4000` (Client Service)
- `PORT=4001` (Command Service)  
- `PORT=4002` (Query Service)
- `EVENT_BUS_MODULE=LocalEventBus` (ローカルイベントバス使用)

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
make start             # 全サービスを起動（フロントエンド含む）
make backend           # バックエンドのみ起動
make stop              # サービスを停止
make restart           # サービスを再起動
make test              # テストを実行
make logs              # ログを表示
make reset             # データをリセット
make seed              # シードデータを投入
make status            # サービスの状態を確認
make clean             # ビルドアーティファクトを削除
```

## Saga の実装

分散トランザクションを実装する場合：

### 1. Saga 定義の作成

```elixir
defmodule Shared.Domain.Sagas.OrderProcessingSaga do
  use Shared.Infrastructure.Saga.SagaDefinition

  saga "order_processing" do
    step :reserve_inventory, 
      compensation: :cancel_inventory_reservation
    
    step :process_payment,
      compensation: :refund_payment
      
    step :arrange_shipping,
      compensation: :cancel_shipping
  end
end
```

### 2. ステップハンドラーの実装

各ステップと補償ハンドラーを実装します。

### 3. Saga の起動

```elixir
# コマンドハンドラー内で Saga を起動
SagaExecutor.start_saga(
  OrderProcessingSaga,
  %{order_id: order.id, items: order.items}
)
```
# 開発ガイド

## 開発環境のセットアップ

### 必要なツール

#### 必須

- **Elixir**: 1.18 以上
- **Erlang/OTP**: 26 以上
- **Docker**: 20.10 以上
- **Docker Compose**: 2.0 以上
- **PostgreSQL クライアント**: psql コマンド

#### 推奨

- **asdf**: バージョン管理ツール
- **direnv**: 環境変数管理
- **VS Code**: エディタ
  - ElixirLS 拡張機能
  - GraphQL 拡張機能

### インストール手順

#### 1. Elixir/Erlang のインストール

##### asdf を使用する場合（推奨）

```bash
# asdf のインストール
git clone https://github.com/asdf-vm/asdf.git ~/.asdf
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc

# Elixir/Erlang プラグインの追加
asdf plugin add erlang
asdf plugin add elixir

# バージョンのインストール
asdf install erlang 26.0
asdf install elixir 1.18-otp-26

# デフォルトバージョンの設定
asdf global erlang 26.0
asdf global elixir 1.18-otp-26
```

##### Homebrew を使用する場合（macOS）

```bash
brew install elixir
```

#### 2. プロジェクトのセットアップ

```bash
# リポジトリのクローン
git clone <repository-url>
cd elixir-cqrs

# 依存関係のインストール
mix deps.get
mix deps.compile
```

#### 3. Docker 環境の構築

```bash
# Docker イメージのビルドとコンテナ起動
docker compose up -d

# コンテナの状態確認
docker compose ps

# ログの確認
docker compose logs -f
```

#### 4. データベースの初期化

```bash
# データベースとテーブルの作成
./scripts/setup_db.sh

# 手動で実行する場合
mix ecto.create
mix ecto.migrate
```

### 環境変数の設定

開発環境では `.env` ファイルを使用して環境変数を管理します：

```bash
# .env.example をコピー
cp .env.example .env.local

# 必要に応じて編集
vim .env.local
```

環境変数の詳細な説明と設定方法については [ENVIRONMENT_VARIABLES.md](ENVIRONMENT_VARIABLES.md) を参照してください。

### VS Code の設定

#### .vscode/settings.json

```json
{
  "elixirLS.mixEnv": "dev",
  "elixirLS.dialyzerEnabled": true,
  "elixirLS.fetchDeps": true,
  "elixirLS.suggestSpecs": true,
  "editor.formatOnSave": true,
  "files.trimTrailingWhitespace": true,
  "files.associations": {
    "*.ex": "elixir",
    "*.exs": "elixir",
    "*.eex": "html-eex",
    "*.leex": "html-eex"
  }
}
```

#### 推奨拡張機能

- ElixirLS: Elixir support and debugger
- GraphQL: GraphQL syntax support
- Docker
- GitLens

### 開発ツール

```bash
# コードフォーマット
mix format

# 静的解析
mix credo --strict

# 型チェック
mix dialyzer

# テスト実行
mix test

# カバレッジレポート
mix coveralls.html

# すべてをチェック
mix check
```

## コーディング規約

### モジュール構造

```elixir
defmodule MyApp.Context.Module do
  @moduledoc """
  モジュールの説明
  """

  alias MyApp.OtherModule
  import MyApp.Helpers

  @type t :: %__MODULE__{
    field: String.t()
  }

  defstruct [:field]

  # Public API
  @doc """
  関数の説明
  """
  @spec public_function(arg :: term()) :: {:ok, result :: term()} | {:error, reason :: term()}
  def public_function(arg) do
    # 実装
  end

  # Private functions
  defp private_function do
    # 実装
  end
end
```

### エラーハンドリング

```elixir
# タプルベースのエラーハンドリング
case do_something() do
  {:ok, result} -> handle_success(result)
  {:error, reason} -> handle_error(reason)
end

# with 文を使った複数の操作
with {:ok, user} <- get_user(id),
     {:ok, updated} <- update_user(user, params),
     {:ok, _} <- send_notification(updated) do
  {:ok, updated}
else
  {:error, :not_found} -> {:error, "User not found"}
  {:error, reason} -> {:error, reason}
end
```

## 開発ワークフロー

### 1. サービスの起動

```bash
# すべてのサービスを起動
./scripts/start_services.sh

# または個別に起動
iex -S mix run --no-halt # Command Service
iex -S mix run --no-halt # Query Service
iex -S mix phx.server    # Client Service
```

### 2. 対話的な開発

```elixir
# IEx で接続
iex -S mix

# モジュールのリロード
r ModuleName

# デバッグ
require IEx
IEx.pry # ブレークポイント
```

### 3. テストの実行

```bash
# すべてのテスト
mix test

# 特定のファイル
mix test test/path/to/test.exs

# 特定の行
mix test test/path/to/test.exs:42

# カバレッジ付き
mix coveralls.html
```

## 新機能の追加

### 1. 新しいコマンドの追加

```elixir
# 1. コマンドの定義
# apps/command_service/lib/command_service/application/commands/product_commands.ex
defmodule CommandService.Application.Commands.ProductCommands.DiscountProduct do
  use Shared.Domain.BaseCommand

  embedded_schema do
    field :product_id, :binary_id
    field :discount_percentage, :integer
  end
end

# 2. アグリゲートにロジックを追加
# apps/command_service/lib/command_service/domain/aggregates/product_aggregate.ex
def execute(aggregate, %DiscountProduct{} = command) do
  # ビジネスロジックの実装
  event = ProductDiscounted.new(%{
    id: aggregate.id,
    discount_percentage: command.discount_percentage,
    discounted_at: DateTime.utc_now()
  })

  {:ok, apply_event(aggregate, event), [event]}
end

# 3. ハンドラーに処理を追加
# apps/command_service/lib/command_service/application/handlers/product_command_handler.ex
def handle(%DiscountProduct{} = command) do
  # 実装
end
```

### 2. 新しいクエリの追加

```elixir
# 1. クエリハンドラーの実装
# apps/query_service/lib/query_service/application/handlers/product_query_handler.ex
def handle_query(%{type: "get_discounted_products", min_discount: min_discount}) do
  ProductRepository.get_discounted_products(min_discount)
end

# 2. リポジトリメソッドの追加
# apps/query_service/lib/query_service/infrastructure/repositories/product_repository.ex
def get_discounted_products(min_discount) do
  query = from p in Product,
    where: p.discount_percentage >= ^min_discount,
    order_by: [desc: p.discount_percentage]

  products = Repo.all(query)
  {:ok, Enum.map(products, &to_domain_model/1)}
end
```

### 3. GraphQL の拡張

```elixir
# 1. スキーマに型を追加
# apps/client_service/lib/client_service/graphql/types/product.ex
field :discount_product, :product do
  arg :product_id, non_null(:id)
  arg :discount_percentage, non_null(:integer)

  resolve &ProductResolver.discount_product/3
end

# 2. リゾルバーの実装
# apps/client_service/lib/client_service/graphql/resolvers/product_resolver_pubsub.ex
def discount_product(_parent, %{product_id: id, discount_percentage: discount}, _resolution) do
  command = %{
    type: "discount_product",
    product_id: id,
    discount_percentage: discount
  }

  case send_command(command) do
    {:ok, result} -> {:ok, result}
    {:error, reason} -> {:error, reason}
  end
end
```

#### Subscription の追加

```elixir
# 1. スキーマにサブスクリプションを追加
# apps/client_service/lib/client_service/graphql/schema.ex
subscription do
  field :product_updated, :product do
    arg :product_id, non_null(:id)

    config fn args, _res ->
      {:ok, topic: "product:#{args.product_id}"}
    end

    trigger [:update_product, :discount_product],
      topic: fn
        %{product_id: id} -> "product:#{id}"
        _ -> []
      end
  end
end

# 2. WebSocket エンドポイントの確認
# apps/client_service/lib/client_service_web/endpoint.ex
socket "/socket", ClientServiceWeb.AbsintheSocket,
  websocket: true,
  longpoll: false

# 3. クライアント側の実装
# WebSocket 接続: ws://localhost:4000/socket
```

## テスト

### ユニットテスト

```elixir
# test/my_module_test.exs
defmodule MyModuleTest do
  use ExUnit.Case, async: true

  describe "my_function/1" do
    test "returns expected result" do
      assert {:ok, result} = MyModule.my_function("input")
      assert result == "expected"
    end

    test "handles error case" do
      assert {:error, reason} = MyModule.my_function(nil)
      assert reason == :invalid_input
    end
  end
end
```

### 統合テスト

```elixir
# test/integration/command_flow_test.exs
defmodule CommandFlowTest do
  use ExUnit.Case

  setup do
    # データベースのクリーンアップ
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    # テストデータの準備
    {:ok, category} = create_test_category()

    {:ok, category: category}
  end

  test "complete command flow", %{category: category} do
    # コマンドの実行
    command = %CreateProduct{
      name: "Test Product",
      category_id: category.id
    }

    assert {:ok, aggregate} = CommandBus.dispatch(command)

    # イベントの確認
    assert {:ok, events} = EventStore.get_events(aggregate.id)
    assert length(events) == 1

    # Read Model の確認
    Process.sleep(100) # プロジェクションの処理待ち
    assert {:ok, product} = ProductRepository.get(aggregate.id)
    assert product.name == "Test Product"
  end
end
```

## プロジェクションの管理

プロジェクションはイベントストアから読み取り専用モデル（Query DB）を構築する重要な機能です。

### 基本的な操作

```bash
# デモデータを投入してプロジェクションをテスト
mix run scripts/seed_demo_data.exs

# プロジェクションのステータス確認（IEx）
GenServer.call(QueryService.Infrastructure.ProjectionManager, :get_status)

# リアルタイム同期のテスト
./scripts/test_realtime_sync.sh
```

詳細な仕組みとデータフローについては [DATA_FLOW.md](DATA_FLOW.md#イベントの伝播フロー) を参照してください。

## デバッグツール

### Observer

```elixir
# IEx から起動
:observer.start()
```

プロセス、メモリ、ETS テーブルなどを監視できます。

### ログレベルの変更

```elixir
# 実行時に変更
Logger.configure(level: :debug)

# 特定のモジュールのみ
Logger.configure_backend(:console,
  [metadata: [:module],
   format: "$time $metadata[$level] $message\n"])
```

### リモートシェル

```bash
# 実行中のノードに接続
iex --name debug@localhost --cookie my-cookie --remsh app@localhost
```

### IEx での調査

```elixir
# プロセスの状態を確認
:sys.get_state(ProcessName)

# イベントストアの内容を確認
EventStore.get_events("aggregate-id")

# Read Model のデータを確認
QueryService.Infrastructure.Repositories.ProductRepository.list()

# メトリクスの確認
:telemetry.execute([:my_app, :metric], %{count: 1}, %{})
```

## Frontend 開発

### 新しいページ

#### /database-status

データベースの状態を確認できるダッシュボード。

```typescript
// frontend/app/database-status/page.tsx
// データベース状態の表示
```

#### /pubsub

PubSub メッセージをリアルタイムで監視できるモニタリングページ。

```typescript
// frontend/app/pubsub/page.tsx
// PubSub メッセージのリアルタイム表示
// トピック別フィルタリング
// 統計情報のグラフ表示
```

### GraphQL サブスクリプションの使用

```typescript
// frontend/lib/apollo-client.ts
import { createClient } from "graphql-ws";

const wsClient = createClient({
  url: "ws://localhost:4000/socket",
});

// サブスクリプションの例
const subscription = gql`
  subscription OnEventStream {
    eventStream {
      id
      eventType
      eventData
      occurredAt
    }
  }
`;
```

### コンポーネントライブラリ

shadcn/ui を使用した UI コンポーネントが利用可能です：

```bash
# 新しいコンポーネントの追加
npx shadcn-ui@latest add button
npx shadcn-ui@latest add card
npx shadcn-ui@latest add tabs
```

## トラブルシューティング

開発中によく発生する問題については、[TROUBLESHOOTING.md](TROUBLESHOOTING.md) を参照してください。

特に以下のセクションが開発に関連します：

- [開発環境](#開発環境) - 依存関係やコンパイルエラーの解決
- [データベース関連](#データベース関連) - 接続エラーやマイグレーションの問題
- [サービス間通信](#サービス間通信) - Phoenix PubSub やノード間通信の問題

## スクリプト一覧

### セットアップ関連

| スクリプト       | 説明                      |
| ---------------- | ------------------------- |
| `setup_infra.sh` | Docker 環境のセットアップ |
| `setup_db.sh`    | データベースの初期化      |
| `start_all.sh`   | すべてのサービスを起動    |
| `stop_all.sh`    | すべてのサービスを停止    |

### テスト関連

| スクリプト                  | 説明                     |
| --------------------------- | ------------------------ |
| `test_realtime_sync.sh`     | リアルタイム同期のテスト |
| `seed_demo_data.exs`        | デモデータの投入         |
| `check_node_connection.exs` | ノード間の接続テスト     |
| `fix_node_startup.sh`       | ノード起動問題の修正     |

## パフォーマンスチューニング

### ETS テーブルの監視

```elixir
# テーブル一覧
:ets.all()

# テーブルの情報
:ets.info(:table_name)
```

### プロセスの監視

```elixir
# プロセス数
length(Process.list())

# メモリ使用量
:erlang.memory()
```

### データベース

```elixir
# インデックスの追加
create index(:products, [:category_id])
create index(:products, [:created_at])

# 複合インデックス
create index(:products, [:category_id, :active])
```

### 並行処理

```elixir
# Task による並列処理
tasks = Enum.map(items, fn item ->
  Task.async(fn -> process_item(item) end)
end)

results = Task.await_many(tasks, 5000)

# GenStage による処理
defmodule Producer do
  use GenStage

  def handle_demand(demand, state) do
    events = fetch_events(demand)
    {:noreply, events, state}
  end
end
```

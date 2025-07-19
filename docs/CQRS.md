# CQRS パターン

## CQRS とは

CQRS (Command Query Responsibility Segregation) は、データの読み取り（Query）と書き込み（Command）を分離するアーキテクチャパターンです。

## なぜ CQRS を使うのか

1. **パフォーマンスの最適化**: 読み取りと書き込みで異なる最適化が可能
2. **スケーラビリティ**: 読み取りと書き込みを独立してスケール
3. **複雑性の管理**: ビジネスロジックとクエリロジックの分離
4. **柔軟性**: 読み取りモデルを用途に応じて最適化

## 実装の詳細

### コマンド側（書き込み）

#### 1. コマンド

ビジネス操作を表現するデータ構造です。

```elixir
defmodule CommandService.Application.Commands.CategoryCommands do
  defmodule CreateCategory do
    @enforce_keys [:name]
    defstruct [:id, :name, :description, :parent_id]

    def new(params) do
      %__MODULE__{
        id: Map.get(params, :id, UUID.uuid4()),
        name: params.name,
        description: Map.get(params, :description),
        parent_id: Map.get(params, :parent_id)
      }
    end
  end
end
```

#### 2. コマンドハンドラ

コマンドを受け取り、ビジネスロジックを実行します。

```elixir
defmodule CommandService.Application.Handlers.CategoryCommandHandler do
  def handle(%CreateCategory{} = command) do
    # 1. アグリゲートを作成または取得
    aggregate = CategoryAggregate.new()

    # 2. コマンドを実行
    case CategoryAggregate.execute(aggregate, command) do
      {:ok, updated_aggregate, events} ->
        # 3. イベントを保存
        save_events(events)
        # 4. イベントを発行
        publish_events(events)
        {:ok, updated_aggregate}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

#### 3. アグリゲート

ビジネスルールを実装し、状態を管理します。

```elixir
defmodule CommandService.Domain.Aggregates.CategoryAggregate do
  def execute(aggregate, %CreateCategory{} = command) do
    # ビジネスルールの検証
    if aggregate.created_at do
      {:error, "Category already created"}
    else
      # イベントの生成
      event = CategoryCreated.new(%{
        id: aggregate.id,
        name: command.name,
        description: command.description,
        created_at: DateTime.utc_now()
      })

      # アグリゲートの更新
      updated_aggregate = apply_event(aggregate, event)
      {:ok, updated_aggregate, [event]}
    end
  end
end
```

### クエリ側（読み取り）

#### 1. プロジェクション

イベントから読み取り用のモデルを構築します。

```elixir
defmodule QueryService.Infrastructure.Projections.CategoryProjection do
  def handle_event(%CategoryCreated{} = event) do
    # リードモデルに保存
    CategoryRepository.create(%{
      id: event.id.value,
      name: event.name.value,
      description: event.description,
      parent_id: event.parent_id && event.parent_id.value,
      created_at: event.created_at
    })
  end

  def handle_event(%CategoryUpdated{} = event) do
    # リードモデルを更新
    CategoryRepository.update(event.id.value, %{
      name: event.name && event.name.value,
      description: event.description,
      updated_at: event.updated_at
    })
  end
end
```

#### 2. クエリハンドラ

クエリを受け取り、リードモデルからデータを取得します。

```elixir
defmodule QueryService.Application.QueryHandlers.CategoryQueryHandler do
  def handle_query(%{type: "get_category", id: id}) do
    case CategoryRepository.get(id) do
      {:ok, category} ->
        # キャッシュから取得またはDBから取得
        Cache.fetch("category:#{id}", fn ->
          {:ok, category}
        end)

      {:error, :not_found} ->
        {:error, "Category not found"}
    end
  end

  def handle_query(%{type: "list_categories", filters: filters}) do
    categories = CategoryRepository.list(filters)
    {:ok, categories}
  end
end
```

#### 3. リードモデル

クエリに最適化されたデータ構造です。

```elixir
defmodule QueryService.Domain.ReadModels.Category do
  use Ecto.Schema

  schema "categories" do
    field :name, :string
    field :description, :string
    field :parent_id, :string
    field :product_count, :integer, virtual: true
    field :active, :boolean, default: true

    timestamps()
  end
end
```

## データフローの例

### カテゴリ作成のフロー

```
1. GraphQL Mutation
   mutation {
     createCategory(input: {name: "家電"}) {
       id
       name
     }
   }

2. Client Service
   - GraphQL リゾルバーがコマンドを作成
   - Phoenix PubSub でコマンドを送信

3. Command Service
   - コマンドハンドラが受信
   - アグリゲートでビジネスロジック実行
   - CategoryCreated イベントを生成
   - イベントストアに保存
   - Phoenix PubSub でイベントを配信

4. Query Service
   - プロジェクションがイベントを受信
   - リードモデルを更新
   - キャッシュを無効化

5. Client Service
   - クエリでデータを取得
   - GraphQL レスポンスを返す
```

## 実装のポイント

### 1. 結果整合性

コマンドとクエリは非同期で処理されるため、一時的な不整合が発生します。

```elixir
# コマンド実行後、すぐにクエリしても最新データが取得できない可能性
{:ok, category} = create_category(name: "家電")
# この時点ではまだプロジェクションが更新されていない可能性
{:ok, categories} = list_categories()
```

### 2. イベントの順序保証

同一アグリゲートのイベントは順序を保証します。

```elixir
# イベントストアでバージョン管理
def append_events(aggregate_id, events, expected_version) do
  # 楽観的ロックでバージョンチェック
  if current_version == expected_version do
    save_events_with_version(events, expected_version + 1)
  else
    {:error, :version_conflict}
  end
end
```

### 3. 読み取りモデルの再構築

イベントから読み取りモデルを再構築できます。

```elixir
defmodule ProjectionRebuilder do
  def rebuild_all do
    # すべてのイベントを取得
    events = EventStore.get_all_events()

    # プロジェクションをクリア
    clear_read_models()

    # イベントを再生
    Enum.each(events, &ProjectionManager.handle_event/1)
  end
end
```

## メリットとデメリット

### メリット

1. **パフォーマンス**: 読み取りと書き込みを独立して最適化
2. **スケーラビリティ**: 負荷に応じて個別にスケール
3. **柔軟性**: 複数の読み取りモデルを作成可能
4. **監査**: すべての変更がイベントとして記録

### デメリット

1. **複雑性**: システムが複雑になる
2. **結果整合性**: リアルタイムの一貫性が保証されない
3. **学習曲線**: 新しい概念の理解が必要
4. **インフラ**: より多くのコンポーネントが必要

## ベストプラクティス

1. **コマンドは動詞で命名**: CreateCategory, UpdateProduct など
2. **クエリは名詞で命名**: Category, ProductList など
3. **イベントは過去形で命名**: CategoryCreated, ProductUpdated など
4. **読み取りモデルは用途別に作成**: 一覧表示用、詳細表示用など
5. **キャッシュの活用**: 頻繁にアクセスされるデータはキャッシュ

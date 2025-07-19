# テスト戦略ガイド

Elixir CQRS/ES プロジェクトの包括的なテスト戦略とベストプラクティスです。

## 📋 目次

- [テスト戦略の概要](#テスト戦略の概要)
- [テストピラミッド](#テストピラミッド)
- [ユニットテスト](#ユニットテスト)
- [統合テスト](#統合テスト)
- [E2E テスト](#e2e-テスト)
- [プロパティベーステスト](#プロパティベーステスト)
- [パフォーマンステスト](#パフォーマンステスト)
- [テストのベストプラクティス](#テストのベストプラクティス)

## テスト戦略の概要

### テストの原則

1. **高速なフィードバック** - テストは素早く実行され、開発者に即座にフィードバックを提供
2. **独立性** - 各テストは他のテストに依存せず、任意の順序で実行可能
3. **再現性** - 同じ条件下では常に同じ結果を返す
4. **保守性** - テストコードも本番コードと同様に保守しやすく設計

### テスト環境

```elixir
# config/test.exs
config :shared, Shared.Infrastructure.EventStore.Repo,
  database: "event_store_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :logger, level: :warning
```

## テストピラミッド

```
        E2E Tests
       /    ⬆    \
      / 統合テスト \
     /      ⬆      \
    / ユニットテスト \
   /________________\
```

- **ユニットテスト** (70%): 高速、大量、個別の関数やモジュール
- **統合テスト** (20%): 中速、モジュール間の連携
- **E2E テスト** (10%): 低速、少量、ユーザーシナリオ

## ユニットテスト

### ドメインロジックのテスト

```elixir
# test/domain/aggregates/order_aggregate_test.exs
defmodule CommandService.Domain.Aggregates.OrderAggregateTest do
  use ExUnit.Case, async: true
  alias CommandService.Domain.Aggregates.OrderAggregate
  alias Shared.Domain.Events.OrderEvents.{OrderCreated, OrderCancelled}

  describe "create_order/1" do
    test "正常な注文作成でイベントが生成される" do
      params = %{
        order_id: "order-123",
        user_id: "user-456",
        items: [%{product_id: "prod-1", quantity: 2, price: 1000}],
        total_amount: 2000
      }

      assert {:ok, %OrderCreated{} = event} = OrderAggregate.create_order(params)
      assert event.order_id == params.order_id
      assert event.total_amount == params.total_amount
    end

    test "アイテムが空の場合はエラーを返す" do
      params = %{order_id: "order-123", items: []}
      
      assert {:error, :empty_items} = OrderAggregate.create_order(params)
    end
  end

  describe "apply_event/2" do
    test "OrderCreated イベントで状態が更新される" do
      event = %OrderCreated{
        order_id: "order-123",
        status: "pending",
        total_amount: 2000
      }

      state = OrderAggregate.apply_event(%{}, event)

      assert state.order_id == "order-123"
      assert state.status == "pending"
      assert state.total_amount == 2000
    end
  end
end
```

### Value Object のテスト

```elixir
# test/domain/value_objects/money_test.exs
defmodule Shared.Domain.ValueObjects.MoneyTest do
  use ExUnit.Case, async: true
  alias Shared.Domain.ValueObjects.Money

  describe "new/2" do
    test "正の金額で Money を作成できる" do
      assert {:ok, money} = Money.new(1000, "JPY")
      assert Money.amount(money) == 1000
      assert Money.currency(money) == "JPY"
    end

    test "負の金額はエラーを返す" do
      assert {:error, :invalid_amount} = Money.new(-100, "JPY")
    end

    test "無効な通貨コードはエラーを返す" do
      assert {:error, :invalid_currency} = Money.new(1000, "INVALID")
    end
  end

  describe "add/2" do
    test "同じ通貨の Money を加算できる" do
      {:ok, money1} = Money.new(1000, "JPY")
      {:ok, money2} = Money.new(2000, "JPY")
      
      assert {:ok, result} = Money.add(money1, money2)
      assert Money.amount(result) == 3000
    end

    test "異なる通貨の加算はエラーを返す" do
      {:ok, money1} = Money.new(1000, "JPY")
      {:ok, money2} = Money.new(2000, "USD")
      
      assert {:error, :currency_mismatch} = Money.add(money1, money2)
    end
  end
end
```

### モックとスタブ

```elixir
# test/support/mocks.ex
Mox.defmock(MockEventStore, for: Shared.Infrastructure.EventStore.Behaviour)
Mox.defmock(MockCommandBus, for: CommandService.Infrastructure.CommandBus.Behaviour)

# test/application/handlers/order_command_handler_test.exs
defmodule OrderCommandHandlerTest do
  use ExUnit.Case, async: true
  import Mox

  setup :verify_on_exit!

  test "CreateOrder コマンドがイベントストアに保存される" do
    command = %CreateOrder{order_id: "order-123"}
    
    expect(MockEventStore, :append_events, fn aggregate_id, events, _version ->
      assert aggregate_id == "order-123"
      assert length(events) == 1
      {:ok, 1}
    end)

    assert {:ok, _} = OrderCommandHandler.handle(command)
  end
end
```

## 統合テスト

### データベース統合テスト

```elixir
# test/integration/event_store_test.exs
defmodule EventStoreIntegrationTest do
  use SharedCase  # Ecto.Sandbox を設定するカスタムケース
  alias Shared.Infrastructure.EventStore

  describe "イベントの永続化と読み込み" do
    test "イベントを保存して読み込める" do
      aggregate_id = "test-#{Ecto.UUID.generate()}"
      events = [
        %TestEvent{id: "1", data: "first"},
        %TestEvent{id: "2", data: "second"}
      ]

      # イベントを保存
      assert {:ok, version} = EventStore.append_events(aggregate_id, events, 0)
      assert version == 2

      # イベントを読み込み
      assert {:ok, loaded_events} = EventStore.get_events(aggregate_id)
      assert length(loaded_events) == 2
      assert Enum.map(loaded_events, & &1.data) == ["first", "second"]
    end

    test "バージョン競合を検出する" do
      aggregate_id = "conflict-test"
      event1 = %TestEvent{id: "1"}
      event2 = %TestEvent{id: "2"}

      # 最初のイベントを保存
      {:ok, _} = EventStore.append_events(aggregate_id, [event1], 0)

      # 同じバージョンで別のイベントを保存しようとする
      assert {:error, %VersionConflictError{}} = 
        EventStore.append_events(aggregate_id, [event2], 0)
    end
  end
end
```

### サービス間通信のテスト

```elixir
# test/integration/command_bus_integration_test.exs
defmodule CommandBusIntegrationTest do
  use IntegrationCase
  
  setup do
    # テスト用のサービスを起動
    start_supervised!(CommandService.Application)
    start_supervised!(QueryService.Application)
    :ok
  end

  test "コマンドがクエリ側に反映される" do
    # コマンドを送信
    command = %CreateProduct{
      product_id: "prod-#{Ecto.UUID.generate()}",
      name: "Test Product",
      price: 1000
    }
    
    assert {:ok, _} = RemoteCommandBus.dispatch(command)

    # イベントが伝播するのを待つ
    Process.sleep(100)

    # クエリ側で確認
    assert {:ok, product} = ProductRepository.get(command.product_id)
    assert product.name == "Test Product"
    assert product.price == 1000
  end
end
```

### Saga の統合テスト

```elixir
# test/integration/order_saga_integration_test.exs
defmodule OrderSagaIntegrationTest do
  use IntegrationCase
  alias CommandService.Domain.Sagas.OrderSaga

  test "注文 Saga の完全なフロー" do
    saga = OrderSaga.new("order-123", %{
      user_id: "user-456",
      items: [%{product_id: "prod-1", quantity: 2}],
      total_amount: 2000
    })

    # Saga を開始
    assert {:ok, saga, commands} = SagaCoordinator.start_saga(saga)
    assert length(commands) == 3  # Reserve, Process, Arrange

    # 各ステップの成功を記録
    saga = OrderSaga.handle_event(saga, %InventoryReserved{})
    saga = OrderSaga.handle_event(saga, %PaymentProcessed{})
    saga = OrderSaga.handle_event(saga, %ShippingArranged{})

    assert saga.status == :completed
  end

  test "支払い失敗時の補償トランザクション" do
    saga = create_saga_at_payment_stage()

    # 支払い失敗イベント
    saga = OrderSaga.handle_event(saga, %PaymentFailed{reason: "insufficient_funds"})
    
    # 補償コマンドが生成される
    assert {:ok, saga, commands} = SagaCoordinator.process_saga(saga)
    assert Enum.any?(commands, &match?(%ReleaseInventory{}, &1))
    assert saga.status == :failed
  end
end
```

## E2E テスト

### GraphQL E2E テスト

```elixir
# test/e2e/graphql_e2e_test.exs
defmodule GraphQLEndToEndTest do
  use E2ECase
  
  test "商品の作成から注文までの完全なフロー" do
    # 1. 商品を作成
    mutation = """
    mutation CreateProduct($input: CreateProductInput!) {
      createProduct(input: $input) {
        product {
          id
          name
          price
        }
      }
    }
    """
    
    variables = %{
      input: %{
        name: "E2E Test Product",
        price: 1500,
        category_id: create_test_category().id
      }
    }
    
    assert {:ok, %{data: %{"createProduct" => result}}} = 
      Absinthe.run(mutation, Schema, variables: variables)
    
    product_id = result["product"]["id"]
    
    # 2. 商品を検索
    query = """
    query GetProduct($id: ID!) {
      product(id: $id) {
        id
        name
        stock
      }
    }
    """
    
    assert {:ok, %{data: %{"product" => product}}} = 
      Absinthe.run(query, Schema, variables: %{id: product_id})
    
    # 3. 注文を作成
    order_mutation = """
    mutation CreateOrder($input: CreateOrderInput!) {
      createOrder(input: $input) {
        order {
          id
          status
          total
        }
      }
    }
    """
    
    order_variables = %{
      input: %{
        items: [%{product_id: product_id, quantity: 1}]
      }
    }
    
    assert {:ok, %{data: %{"createOrder" => order_result}}} = 
      Absinthe.run(order_mutation, Schema, variables: order_variables)
    
    assert order_result["order"]["status"] == "pending"
  end
end
```

### WebSocket E2E テスト

```elixir
# test/e2e/websocket_e2e_test.exs
defmodule WebSocketEndToEndTest do
  use E2ECase
  use ChannelCase

  test "リアルタイム更新の受信" do
    # WebSocket 接続
    {:ok, socket} = connect(UserSocket, %{})
    {:ok, _, socket} = subscribe_and_join(socket, "products:lobby", %{})

    # 別のプロセスから商品を更新
    Task.async(fn ->
      Process.sleep(100)
      ProductContext.update_product("prod-1", %{price: 2000})
    end)

    # 更新通知を受信
    assert_push "product_updated", %{
      product_id: "prod-1",
      changes: %{price: 2000}
    }, 1000
  end
end
```

## プロパティベーステスト

### StreamData を使用したテスト

```elixir
# test/property/money_property_test.exs
defmodule MoneyPropertyTest do
  use ExUnit.Case
  use ExUnitProperties
  alias Shared.Domain.ValueObjects.Money

  property "Money の加算は可換である" do
    check all amount1 <- positive_integer(),
              amount2 <- positive_integer(),
              currency <- member_of(["JPY", "USD", "EUR"]) do
      
      {:ok, money1} = Money.new(amount1, currency)
      {:ok, money2} = Money.new(amount2, currency)
      
      {:ok, result1} = Money.add(money1, money2)
      {:ok, result2} = Money.add(money2, money1)
      
      assert Money.amount(result1) == Money.amount(result2)
    end
  end

  property "Money の加算は結合的である" do
    check all amounts <- list_of(positive_integer(), min_length: 3),
              currency <- member_of(["JPY", "USD", "EUR"]) do
      
      moneys = Enum.map(amounts, fn amount ->
        {:ok, money} = Money.new(amount, currency)
        money
      end)
      
      [a, b, c | _] = moneys
      
      # (a + b) + c
      {:ok, ab} = Money.add(a, b)
      {:ok, result1} = Money.add(ab, c)
      
      # a + (b + c)
      {:ok, bc} = Money.add(b, c)
      {:ok, result2} = Money.add(a, bc)
      
      assert Money.amount(result1) == Money.amount(result2)
    end
  end
end
```

### イベントソーシングのプロパティテスト

```elixir
# test/property/event_sourcing_property_test.exs
defmodule EventSourcingPropertyTest do
  use ExUnit.Case
  use ExUnitProperties

  property "イベントの再生で同じ状態が復元される" do
    check all commands <- list_of(command_generator(), min_length: 1, max_length: 20) do
      # コマンドを実行してイベントを生成
      {events, final_state} = Enum.reduce(commands, {[], %{}}, fn cmd, {evts, state} ->
        case OrderAggregate.execute(state, cmd) do
          {:ok, new_events} ->
            new_state = Enum.reduce(new_events, state, &OrderAggregate.apply_event/2)
            {evts ++ new_events, new_state}
          _ ->
            {evts, state}
        end
      end)
      
      # イベントを再生
      replayed_state = Enum.reduce(events, %{}, &OrderAggregate.apply_event/2)
      
      # 同じ状態になることを確認
      assert final_state == replayed_state
    end
  end

  defp command_generator do
    one_of([
      gen all id <- string(:alphanumeric, min_length: 10) do
        %CreateOrder{order_id: id, items: [%{product_id: "p1", quantity: 1}]}
      end,
      constant(%CancelOrder{reason: "test"}),
      constant(%ConfirmOrder{})
    ])
  end
end
```

## パフォーマンステスト

### 負荷テスト

```elixir
# test/performance/load_test.exs
defmodule LoadTest do
  use ExUnit.Case

  @tag :performance
  test "1000 件の同時コマンド処理" do
    commands = for i <- 1..1000 do
      %CreateProduct{
        product_id: "perf-test-#{i}",
        name: "Product #{i}",
        price: 1000 + i
      }
    end

    start_time = System.monotonic_time(:millisecond)
    
    # 並列実行
    tasks = Enum.map(commands, fn cmd ->
      Task.async(fn -> CommandBus.dispatch(cmd) end)
    end)
    
    results = Task.await_many(tasks, 30_000)
    end_time = System.monotonic_time(:millisecond)
    
    # すべて成功することを確認
    assert Enum.all?(results, &match?({:ok, _}, &1))
    
    # パフォーマンス基準
    duration = end_time - start_time
    assert duration < 10_000, "処理時間が 10 秒を超えています: #{duration}ms"
    
    IO.puts("1000 コマンドの処理時間: #{duration}ms")
    IO.puts("スループット: #{1000 * 1000 / duration} commands/sec")
  end

  @tag :performance
  test "イベントストアの読み込みパフォーマンス" do
    aggregate_id = "perf-aggregate"
    events = for i <- 1..10_000 do
      %TestEvent{sequence: i, data: "Event #{i}"}
    end
    
    # イベントを保存
    EventStore.append_events(aggregate_id, events, 0)
    
    # 読み込みパフォーマンスを測定
    {time, {:ok, loaded_events}} = :timer.tc(fn ->
      EventStore.get_events(aggregate_id)
    end)
    
    assert length(loaded_events) == 10_000
    assert time < 1_000_000, "10,000 イベントの読み込みが 1 秒を超えています"
    
    IO.puts("10,000 イベントの読み込み時間: #{time / 1000}ms")
  end
end
```

### ベンチマークテスト

```elixir
# bench/event_store_bench.exs
defmodule EventStoreBench do
  use Benchfella

  @events for i <- 1..100, do: %TestEvent{id: i}

  setup_all do
    Application.ensure_all_started(:shared)
    {:ok, nil}
  end

  bench "append single event" do
    EventStore.append_events(
      "bench-#{:rand.uniform(10000)}",
      [%TestEvent{id: 1}],
      0
    )
  end

  bench "append 100 events" do
    EventStore.append_events(
      "bench-#{:rand.uniform(10000)}",
      @events,
      0
    )
  end

  bench "read 100 events" do
    aggregate_id = "read-bench"
    EventStore.get_events(aggregate_id)
  end
end
```

## テストのベストプラクティス

### テストの構造

```elixir
defmodule ExampleTest do
  use ExUnit.Case, async: true

  # Setup と Teardown
  setup do
    # テストデータの準備
    user = insert(:user)
    {:ok, user: user}
  end

  # 明確な describe ブロック
  describe "create_order/2" do
    setup %{user: user} do
      product = insert(:product)
      {:ok, product: product}
    end

    test "正常なケース", %{user: user, product: product} do
      # Arrange
      params = build_order_params(user, product)
      
      # Act
      result = OrderService.create_order(user, params)
      
      # Assert
      assert {:ok, order} = result
      assert order.user_id == user.id
    end

    test "在庫不足の場合", %{user: user, product: product} do
      # Arrange
      product = %{product | stock: 0}
      params = build_order_params(user, product)
      
      # Act & Assert
      assert {:error, :out_of_stock} = OrderService.create_order(user, params)
    end
  end
end
```

### テストデータの管理

```elixir
# test/support/factory.ex
defmodule Factory do
  use ExMachina.Ecto, repo: Repo

  def user_factory do
    %User{
      id: Ecto.UUID.generate(),
      email: sequence(:email, &"user#{&1}@example.com"),
      name: "Test User"
    }
  end

  def product_factory do
    %Product{
      id: Ecto.UUID.generate(),
      name: sequence(:name, &"Product #{&1}"),
      price: 1000,
      stock: 100
    }
  end

  def order_factory do
    %Order{
      id: Ecto.UUID.generate(),
      user: build(:user),
      items: [build(:order_item)],
      status: "pending"
    }
  end
end
```

### 非同期処理のテスト

```elixir
defmodule AsyncTest do
  use ExUnit.Case

  test "非同期イベント処理" do
    # テスト用の PubSub をセットアップ
    Phoenix.PubSub.subscribe(MyApp.PubSub, "test_events")
    
    # イベントを発行
    EventBus.publish(%ProductCreated{id: "123"})
    
    # イベントの受信を待つ
    assert_receive {:product_created, %{id: "123"}}, 1000
  end

  test "タイムアウトのテスト" do
    # Process.sleep の代わりに
    ref = make_ref()
    Process.send_after(self(), {ref, :timeout}, 100)
    
    assert_receive {^ref, :timeout}, 200
  end
end
```

### テストのメンテナンス

```elixir
# 共通のアサーションをヘルパーに
defmodule TestHelpers do
  import ExUnit.Assertions

  def assert_event_stored(aggregate_id, event_type) do
    {:ok, events} = EventStore.get_events(aggregate_id)
    assert Enum.any?(events, &(&1.__struct__ == event_type))
  end

  def assert_eventually(fun, timeout \\ 1000) do
    assert wait_until(fun, timeout)
  end

  defp wait_until(fun, timeout) when timeout <= 0 do
    fun.()
  end

  defp wait_until(fun, timeout) do
    if fun.() do
      true
    else
      Process.sleep(10)
      wait_until(fun, timeout - 10)
    end
  rescue
    _ -> wait_until(fun, timeout - 10)
  end
end
```

## テストの実行

### 基本的なテスト実行

```bash
# すべてのテストを実行
mix test

# 特定のファイルのテスト
mix test test/domain/aggregates/order_aggregate_test.exs

# 特定の行のテスト
mix test test/domain/aggregates/order_aggregate_test.exs:42

# タグ付きテストの実行
mix test --only integration
mix test --exclude performance

# 監視モードでテスト
mix test.watch
```

### カバレッジ測定

```bash
# カバレッジレポートを生成
mix coveralls

# HTML レポートを生成
mix coveralls.html

# 最小カバレッジの強制
mix coveralls --minimum-coverage 80
```

### CI/CD でのテスト

```yaml
# .github/workflows/test.yml
name: Test
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v3
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.15'
          otp-version: '26'
      
      - name: Install dependencies
        run: |
          mix deps.get
          mix deps.compile
      
      - name: Run tests
        run: |
          mix test --cover --warnings-as-errors
      
      - name: Run integration tests
        run: |
          mix test --only integration
```

## その他のリソース

- [ExUnit ドキュメント](https://hexdocs.pm/ex_unit/ExUnit.html)
- [Mox - モックライブラリ](https://github.com/dashbitco/mox)
- [StreamData - プロパティテスト](https://github.com/whatyouhide/stream_data)
- [ExMachina - テストファクトリ](https://github.com/thoughtbot/ex_machina)
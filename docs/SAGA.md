# SAGA パターン

## SAGA パターンとは

SAGA パターンは、マイクロサービス環境で分散トランザクションを管理するためのパターンです。長時間実行されるビジネストランザクションを、一連の小さなローカルトランザクションに分割し、各ステップが成功した場合は次のステップに進み、失敗した場合は補償トランザクションでロールバックします。

## なぜ SAGA が必要か

1. **分散トランザクションの課題**: 2 フェーズコミットは分散環境でパフォーマンスと可用性の問題がある
2. **マイクロサービスの自律性**: 各サービスが独立してトランザクションを管理
3. **長時間実行トランザクション**: 外部サービスの呼び出しなど、時間のかかる処理に対応
4. **部分的な失敗の処理**: 一部のステップが失敗しても適切にロールバック

## 実装アーキテクチャ

### コレオグラフィ vs オーケストレーション

このプロジェクトでは**オーケストレーション**方式を採用しています。

- **SagaCoordinator** が中央で SAGA の実行を管理
- 各ステップの実行順序と補償処理を明示的に定義
- 実行状態を永続化して障害復旧に対応

## 実装の詳細

### 1. SAGA の定義

```elixir
defmodule CommandService.Domain.Sagas.OrderSaga do
  @behaviour Shared.Infrastructure.Saga.SagaBehaviour

  alias Shared.Infrastructure.Saga.Step

  @impl true
  def steps do
    [
      %Step{
        name: :reserve_inventory,
        handler: &reserve_inventory/2,
        compensation: &release_inventory/2,
        timeout: 30_000
      },
      %Step{
        name: :process_payment,
        handler: &process_payment/2,
        compensation: &refund_payment/2,
        timeout: 60_000
      },
      %Step{
        name: :confirm_order,
        handler: &confirm_order/2,
        compensation: nil,  # 最終ステップは補償不要
        timeout: 30_000
      }
    ]
  end

  @impl true
  def handle_event(saga_id, event, data) do
    case event do
      %InventoryReserved{} ->
        {:continue, Map.put(data, :inventory_reserved, true)}

      %InventoryReservationFailed{} ->
        {:compensate, "在庫予約に失敗しました"}

      %PaymentProcessed{} ->
        {:continue, Map.put(data, :payment_processed, true)}

      %PaymentFailed{} ->
        {:compensate, "支払い処理に失敗しました"}

      %OrderConfirmed{} ->
        {:complete, data}

      _ ->
        {:continue, data}
    end
  end
end
```

### 2. ステップの実装

#### 在庫予約ステップ

```elixir
defp reserve_inventory(_saga_id, %{items: items, order_id: order_id} = data) do
  # コマンドを作成
  command = %ReserveInventory{
    order_id: order_id,
    items: Enum.map(items, fn item ->
      %{
        product_id: item.product_id,
        quantity: item.quantity
      }
    end)
  }

  # コマンドを送信
  EventBus.publish(:commands, command)

  # ステップのメタデータを返す
  {:ok, Map.put(data, :inventory_command_sent, true)}
end

defp release_inventory(_saga_id, %{order_id: order_id} = data) do
  # 補償コマンドを作成
  command = %ReleaseInventory{
    order_id: order_id
  }

  EventBus.publish(:commands, command)
  {:ok, data}
end
```

#### 支払い処理ステップ

```elixir
defp process_payment(_saga_id, %{order_id: order_id, total_amount: amount, user_id: user_id} = data) do
  command = %ProcessPayment{
    order_id: order_id,
    amount: amount,
    user_id: user_id,
    payment_method: Map.get(data, :payment_method, "credit_card")
  }

  EventBus.publish(:commands, command)
  {:ok, Map.put(data, :payment_command_sent, true)}
end

defp refund_payment(_saga_id, %{order_id: order_id, payment_id: payment_id} = data) do
  if payment_id do
    command = %RefundPayment{
      payment_id: payment_id,
      order_id: order_id,
      reason: "Order cancelled"
    }

    EventBus.publish(:commands, command)
  end

  {:ok, data}
end
```

### 3. SAGA の実行

```elixir
# SAGA の開始
saga_id = UUID.uuid4()
saga_data = %{
  order_id: order.id.value,
  user_id: order.user_id.value,
  items: order.items,
  total_amount: order.total_amount
}

{:ok, _} = SagaCoordinator.start_saga(
  saga_id,
  CommandService.Domain.Sagas.OrderSaga,
  saga_data
)
```

### 4. 状態管理

SAGA の状態は PostgreSQL に永続化されます：

```sql
CREATE TABLE sagas (
  id UUID PRIMARY KEY,
  saga_type VARCHAR(255) NOT NULL,
  current_step VARCHAR(255),
  status VARCHAR(50) NOT NULL,
  data JSONB NOT NULL,
  started_at TIMESTAMP NOT NULL,
  completed_at TIMESTAMP,
  failed_at TIMESTAMP,
  error_message TEXT
);

CREATE TABLE saga_events (
  id UUID PRIMARY KEY,
  saga_id UUID REFERENCES sagas(id),
  event_type VARCHAR(255) NOT NULL,
  event_data JSONB NOT NULL,
  created_at TIMESTAMP NOT NULL
);
```

## エラー処理と補償

### 1. タイムアウト処理

```elixir
def handle_info({:timeout, step_name}, %{saga: saga} = state) do
  Logger.error("Step #{step_name} timed out for saga #{saga.id}")

  # 補償処理を開始
  start_compensation(saga, "Step timeout: #{step_name}")

  {:noreply, state}
end
```

### 2. 補償の実行

```elixir
defp execute_compensation(saga, completed_steps) do
  # 完了したステップを逆順で補償
  completed_steps
  |> Enum.reverse()
  |> Enum.each(fn step ->
    if step.compensation do
      try do
        step.compensation.(saga.id, saga.data)
      rescue
        error ->
          Logger.error("Compensation failed for step #{step.name}: #{inspect(error)}")
      end
    end
  end)
end
```

### 3. リトライ戦略

```elixir
defmodule SagaRetryPolicy do
  def should_retry?(error, attempt) do
    case error do
      {:timeout, _} -> attempt < 3
      {:network_error, _} -> attempt < 5
      _ -> false
    end
  end

  def retry_delay(attempt) do
    # エクスポネンシャルバックオフ
    :timer.seconds(:math.pow(2, attempt))
  end
end
```

## 監視とデバッグ

### 1. メトリクス

```elixir
defmodule Shared.Telemetry.SagaMetrics do
  def setup do
    metrics = [
      counter("saga.started.count", tags: [:saga_type]),
      counter("saga.completed.count", tags: [:saga_type]),
      counter("saga.failed.count", tags: [:saga_type, :step]),
      histogram("saga.duration", tags: [:saga_type], unit: :millisecond),
      histogram("saga.step.duration", tags: [:saga_type, :step], unit: :millisecond)
    ]
  end
end
```

### 2. トレーシング

```elixir
def execute_step(saga, step) do
  OpentelemetryTelemetry.with_span "saga.step.#{step.name}" do
    # スパン属性を設定
    Span.set_attributes([
      {"saga.id", saga.id},
      {"saga.type", saga.saga_type},
      {"step.name", step.name}
    ])

    # ステップを実行
    result = step.handler.(saga.id, saga.data)

    # 結果を記録
    Span.set_attribute("step.result", inspect(result))

    result
  end
end
```

### 3. ログ

```elixir
Logger.metadata(saga_id: saga.id, saga_type: saga.saga_type)

Logger.info("Starting saga", step: step.name)
Logger.error("Saga failed", error: error, step: step.name)
```

## ベストプラクティス

1. **冪等性**: すべてのステップと補償処理は冪等であるべき
2. **タイムアウト**: 各ステップに適切なタイムアウトを設定
3. **状態の永続化**: 各ステップ後に状態を保存
4. **補償の設計**: 補償処理は必ず成功するように設計
5. **監視**: すべての SAGA 実行を監視・アラート設定

## よくある問題と解決策

### 1. 補償の失敗

```elixir
# 補償が失敗した場合のフォールバック
def handle_compensation_failure(saga, step, error) do
  # Dead Letter Queue に送信
  DeadLetterQueue.add(%{
    type: :compensation_failed,
    saga_id: saga.id,
    step: step.name,
    error: error,
    timestamp: DateTime.utc_now()
  })

  # 手動介入のためのアラート
  AlertService.send_critical_alert(
    "Compensation failed for saga #{saga.id} at step #{step.name}"
  )
end
```

### 2. 重複実行の防止

```elixir
# 冪等性キーを使用
def reserve_inventory(saga_id, data) do
  idempotency_key = "#{saga_id}:reserve_inventory"

  case IdempotencyStore.check_and_set(idempotency_key) do
    :ok ->
      # 実際の処理を実行
      do_reserve_inventory(data)

    {:already_processed, result} ->
      {:ok, result}
  end
end
```

### 3. 長時間実行 SAGA

```elixir
# チェックポイントを設定
def long_running_saga do
  [
    %Step{name: :step1, checkpoint: true},
    %Step{name: :step2, checkpoint: true},
    %Step{name: :step3, checkpoint: true}
  ]
end

# チェックポイントから再開
def resume_from_checkpoint(saga_id) do
  case SagaRepository.get_last_checkpoint(saga_id) do
    {:ok, checkpoint} ->
      resume_from_step(saga_id, checkpoint.step_name)

    {:error, :not_found} ->
      start_from_beginning(saga_id)
  end
end
```

## 実装例：OrderSaga

### 概要

OrderSaga は、注文処理フローを SAGA パターンで実装した例です。以下のステップで構成されています：

1. **在庫予約** - 商品の在庫を予約
2. **支払い処理** - 支払いを実行
3. **注文確認** - 注文を確定

### 実行フロー

#### 成功シナリオ

```
1. CreateOrder コマンド受信
   ↓
2. OrderCreated イベント発行
   ↓
3. OrderSaga 開始
   ↓
4. ReserveInventory コマンド送信
   ↓
5. InventoryReserved イベント受信
   ↓
6. ProcessPayment コマンド送信
   ↓
7. PaymentProcessed イベント受信
   ↓
8. ConfirmOrder コマンド送信
   ↓
9. OrderConfirmed イベント受信
   ↓
10. SAGA 完了
```

#### 失敗シナリオ（支払い失敗）

```
1-5. 在庫予約まで成功
   ↓
6. ProcessPayment コマンド送信
   ↓
7. PaymentFailed イベント受信
   ↓
8. 補償処理開始
   ↓
9. ReleaseInventory コマンド送信（在庫解放）
   ↓
10. CancelOrder コマンド送信
   ↓
11. SAGA 完了（注文キャンセル）
```

### GraphQL での使用例

#### 事前準備

```graphql
# カテゴリ作成
mutation {
  createCategory(input: { name: "電子機器", description: "電子機器カテゴリ" }) {
    id
    name
  }
}

# 商品作成（カテゴリIDを使用）
mutation {
  createProduct(
    input: {
      name: "スマートフォン"
      description: "最新モデル"
      price: 80000
      categoryId: "上で作成したカテゴリID"
      stockQuantity: 5
    }
  ) {
    id
    name
    stockQuantity
  }
}
```

#### 注文作成（SAGA 開始）

```graphql
mutation CreateOrder {
  createOrder(
    input: {
      userId: "user-123"
      items: [
        {
          productId: "上で作成した商品ID"
          productName: "スマートフォン"
          quantity: 2
          unitPrice: 80000
        }
      ]
    }
  ) {
    id
    status
    totalAmount
    items {
      productName
      quantity
      unitPrice
    }
  }
}
```

### テストシナリオ

1. **正常系テスト**: 十分な在庫がある商品で注文を作成し、すべてのステップが成功することを確認
2. **在庫不足テスト**: 在庫以上の数量で注文を作成し、SAGA が適切に失敗することを確認
3. **支払い失敗テスト**: 特定の金額（例：999999）で注文を作成し、支払いステップで失敗させ、補償処理が実行されることを確認
4. **タイムアウトテスト**: サービスを停止した状態で注文を作成し、タイムアウトが発生することを確認

### トラブルシューティング

#### SAGA が進まない場合

1. すべてのサービスが起動していることを確認
2. Phoenix PubSub の接続を確認
3. イベントストアのログを確認

#### 補償処理が実行されない場合

1. SAGA の状態を確認

   ```sql
   SELECT * FROM sagas WHERE id = 'saga-id';
   ```

2. イベントログを確認
   ```sql
   SELECT * FROM events WHERE aggregate_id = 'order-id' ORDER BY created_at;
   ```

#### パフォーマンスの問題

1. Jaeger でボトルネックを特定（http://localhost:16686）
2. 各ステップのタイムアウト設定を調整
3. 並列実行可能なステップを識別

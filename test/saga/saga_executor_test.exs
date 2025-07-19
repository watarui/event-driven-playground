defmodule Shared.Infrastructure.Saga.SagaExecutorTest do
  use ExUnit.Case, async: false

  alias CommandService.Domain.Sagas.OrderSaga
  alias Shared.Domain.Events.OrderEvents
  alias Shared.Infrastructure.Saga.SagaExecutor

  setup do
    # サガエグゼキューターを再起動
    :ok = GenServer.stop(SagaExecutor, :normal)
    {:ok, _pid} = SagaExecutor.start_link([])

    :ok
  end

  describe "start_saga/2" do
    test "新しいサガを開始できる" do
      initial_data = %{
        order_id: "order-123",
        user_id: "user-456",
        items: [%{product_id: "prod-1", quantity: 2}],
        total_amount: 10_000
      }

      assert {:ok, saga_id} = SagaExecutor.start_saga(OrderSaga, initial_data)
      assert is_binary(saga_id)

      # アクティブなサガに含まれていることを確認
      active_sagas = SagaExecutor.get_active_sagas()
      assert Map.has_key?(active_sagas, saga_id)
    end
  end

  describe "handle_event/1" do
    test "OrderCreatedイベントで新しいサガを開始する" do
      event = %OrderEvents.OrderCreated{
        id: %{value: "order-789"},
        user_id: %{value: "user-123"},
        items: [%{product_id: "prod-1", quantity: 1}],
        total_amount: %{amount: 5000, currency: "JPY"},
        saga_id: %{value: "saga-456"},
        created_at: DateTime.utc_now()
      }

      # イベントを処理
      SagaExecutor.handle_event(event)

      # 少し待機してから確認
      Process.sleep(100)

      active_sagas = SagaExecutor.get_active_sagas()
      assert Map.has_key?(active_sagas, "saga-456")
    end

    test "既存のサガでイベントを処理する" do
      # サガを開始
      initial_data = %{
        order_id: "order-123",
        user_id: "user-456",
        items: [%{product_id: "prod-1", quantity: 2}],
        total_amount: 10_000
      }
      {:ok, saga_id} = SagaExecutor.start_saga(OrderSaga, initial_data)

      # 在庫予約成功イベントを送信
      event = %OrderEvents.OrderItemReserved{
        order_id: %{value: "order-123"},
        product_id: %{value: "prod-1"},
        quantity: 2,
        reserved_at: DateTime.utc_now()
      }

      SagaExecutor.handle_event(event)

      # 少し待機してから確認
      Process.sleep(100)

      # サガがまだアクティブであることを確認
      active_sagas = SagaExecutor.get_active_sagas()
      assert Map.has_key?(active_sagas, saga_id)
    end
  end

  describe "get_active_sagas/0" do
    test "アクティブなサガのリストを取得できる" do
      # 複数のサガを開始
      {:ok, saga_id1} = SagaExecutor.start_saga(OrderSaga, %{
        order_id: "order-1",
        user_id: "user-1",
        items: [],
        total_amount: 1000
      })

      {:ok, saga_id2} = SagaExecutor.start_saga(OrderSaga, %{
        order_id: "order-2",
        user_id: "user-2",
        items: [],
        total_amount: 2000
      })

      active_sagas = SagaExecutor.get_active_sagas()

      assert Map.has_key?(active_sagas, saga_id1)
      assert Map.has_key?(active_sagas, saga_id2)
      assert map_size(active_sagas) >= 2
    end
  end
end

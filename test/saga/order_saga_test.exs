defmodule CommandService.Domain.Sagas.OrderSagaTest do
  use ExUnit.Case, async: true

  alias CommandService.Domain.Sagas.OrderSaga
  alias Shared.Domain.Events.OrderEvents

  describe "new/2" do
    test "新しいOrderSagaを作成できる" do
      saga_id = "saga-123"
      initial_data = %{
        order_id: "order-456",
        user_id: "user-789",
        items: [
          %{product_id: "prod-1", quantity: 2},
          %{product_id: "prod-2", quantity: 1}
        ],
        total_amount: 15_000
      }

      saga = OrderSaga.new(saga_id, initial_data)

      assert saga.saga_id == saga_id
      assert saga.order_id == "order-456"
      assert saga.user_id == "user-789"
      assert saga.state == :started
      assert saga.current_step == :reserve_inventory
      assert length(saga.items) == 2
      assert saga.total_amount == 15_000
      refute saga.inventory_reserved
      refute saga.payment_processed
      refute saga.shipping_arranged
      refute saga.order_confirmed
    end
  end

  describe "handle_event/2" do
    setup do
      saga = OrderSaga.new("saga-123", %{
        order_id: "order-456",
        user_id: "user-789",
        items: [%{product_id: "prod-1", quantity: 2}],
        total_amount: 10_000
      })

      {:ok, saga: saga}
    end

    test "在庫予約成功イベントを処理する", %{saga: saga} do
      event = %OrderEvents.OrderItemReserved{
        order_id: %{value: "order-456"},
        product_id: %{value: "prod-1"},
        quantity: 2,
        reserved_at: DateTime.utc_now()
      }

      assert {:ok, _commands} = OrderSaga.handle_event(event, saga)
      assert length(commands) == 1

      [command] = commands
      assert command.command_type == "process_payment"
      assert command.order_id == "order-456"
      assert command.amount == 10_000
    end

    test "支払い処理成功イベントを処理する", %{saga: saga} do
      saga = %{saga |
        current_step: :process_payment,
        inventory_reserved: true,
        reservation_ids: ["prod-1"]
      }

      event = %OrderEvents.OrderPaymentProcessed{
        order_id: %{value: "order-456"},
        amount: %{amount: 10_000, currency: "JPY"},
        payment_id: "payment-123",
        processed_at: DateTime.utc_now()
      }

      assert {:ok, _commands} = OrderSaga.handle_event(event, saga)
      assert length(commands) == 1

      [command] = commands
      assert command.command_type == "arrange_shipping"
      assert command.order_id == "order-456"
    end

    test "注文確定イベントを処理する", %{saga: saga} do
      saga = %{saga |
        current_step: :confirm_order,
        inventory_reserved: true,
        payment_processed: true,
        shipping_arranged: true
      }

      event = %OrderEvents.OrderConfirmed{
        id: %{value: "order-456"},
        confirmed_at: DateTime.utc_now()
      }

      assert {:ok, []} = OrderSaga.handle_event(event, saga)
    end
  end

  describe "get_compensation_commands/1" do
    test "各ステップに応じた補償コマンドを返す" do
      saga = OrderSaga.new("saga-123", %{
        order_id: "order-456",
        user_id: "user-789",
        items: [%{product_id: "prod-1", quantity: 2}],
        total_amount: 10_000
      })

      # 在庫予約済みの場合
      saga = %{saga |
        inventory_reserved: true,
        reservation_ids: ["prod-1"]
      }
      commands = OrderSaga.get_compensation_commands(saga)

      assert Enum.any?(commands, fn cmd ->
        cmd.command_type == "release_inventory"
      end)

      # 支払い処理済みの場合
      saga = %{saga |
        payment_processed: true,
        payment_id: "payment-123"
      }
      commands = OrderSaga.get_compensation_commands(saga)

      assert Enum.any?(commands, fn cmd ->
        cmd.command_type == "refund_payment"
      end)

      # 最後に注文キャンセルコマンドがあることを確認
      assert List.last(commands).command_type == "cancel_order"
    end
  end

  describe "completed?/1" do
    test "完了状態を正しく判定する" do
      saga = OrderSaga.new("saga-123", %{})

      refute OrderSaga.completed?(saga)

      completed_saga = %{saga | state: :completed, order_confirmed: true}
      assert OrderSaga.completed?(completed_saga)
    end
  end

  describe "failed?/1" do
    test "失敗状態を正しく判定する" do
      saga = OrderSaga.new("saga-123", %{})

      refute OrderSaga.failed?(saga)

      failed_saga = %{saga | state: :failed}
      assert OrderSaga.failed?(failed_saga)

      compensated_saga = %{saga | state: :compensated}
      assert OrderSaga.failed?(compensated_saga)
    end
  end
end

defmodule CommandService.Application.Handlers.SagaCommandHandler do
  @moduledoc """
  サガコマンドハンドラー

  サガから発行されたコマンドを処理し、結果をイベントとして返します。
  """

  require Logger

  @doc """
  サガコマンドを処理する
  """
  def handle(command) do
    Logger.info("SagaCommandHandler processing command: #{inspect(command)}")

    case command do
      %CommandService.Application.Commands.SagaCommands.ReserveInventory{} ->
        handle_reserve_inventory(command)

      %CommandService.Application.Commands.SagaCommands.ProcessPayment{} ->
        handle_process_payment(command)

      %CommandService.Application.Commands.SagaCommands.ArrangeShipping{} ->
        handle_arrange_shipping(command)

      %CommandService.Application.Commands.SagaCommands.ConfirmOrder{} ->
        handle_confirm_order(command)

      %CommandService.Application.Commands.SagaCommands.ReleaseInventory{} ->
        handle_release_inventory(command)

      %CommandService.Application.Commands.SagaCommands.RefundPayment{} ->
        handle_refund_payment(command)

      %CommandService.Application.Commands.SagaCommands.CancelShipping{} ->
        handle_cancel_shipping(command)

      %CommandService.Application.Commands.SagaCommands.CancelOrder{} ->
        handle_cancel_order(command)

      _ ->
        {:error, "Unknown saga command type"}
    end
  end

  defp handle_reserve_inventory(command) do
    Logger.info("Reserving inventory for order: #{command.order_id}")

    # 在庫予約のデモ実装
    # 実際のアプリケーションでは、在庫サービスに問い合わせる
    case simulate_inventory_check(command.items) do
      {:ok, _} ->
        # 在庫予約成功イベントを発行
        event = %{
          __struct__: Shared.Domain.Events.SagaEvents.InventoryReserved,
          saga_id: command.saga_id,
          order_id: command.order_id,
          items: command.items,
          event_type: "inventory.reserved",
          occurred_at: DateTime.utc_now()
        }

        # イベントを発行
        event_topic = String.to_atom("events:#{event.event_type}")
        Shared.Infrastructure.EventBus.publish(event_topic, event)

        {:ok, %{success: true, event: event}}

      {:error, reason} ->
        # 在庫予約失敗イベントを発行
        event = %{
          __struct__: Shared.Domain.Events.SagaEvents.InventoryReservationFailed,
          saga_id: command.saga_id,
          order_id: command.order_id,
          reason: reason,
          event_type: "inventory.reservation_failed",
          occurred_at: DateTime.utc_now()
        }

        # イベントを発行
        event_topic = String.to_atom("events:#{event.event_type}")
        Shared.Infrastructure.EventBus.publish(event_topic, event)

        {:ok, %{success: false, event: event}}
    end
  end

  defp handle_process_payment(command) do
    Logger.info("Processing payment for order: #{command.order_id}")

    # 支払い処理のデモ実装
    case simulate_payment_processing(command.amount, command.user_id) do
      {:ok, transaction_id} ->
        # 支払い成功イベントを発行
        event = %{
          __struct__: Shared.Domain.Events.SagaEvents.PaymentProcessed,
          saga_id: command.saga_id,
          order_id: command.order_id,
          amount: command.amount,
          transaction_id: transaction_id,
          event_type: "payment.processed",
          occurred_at: DateTime.utc_now()
        }

        # イベントを発行
        event_topic = String.to_atom("events:#{event.event_type}")
        Shared.Infrastructure.EventBus.publish(event_topic, event)

        {:ok, %{success: true, event: event}}

      {:error, reason} ->
        # 支払い失敗イベントを発行
        event = %{
          __struct__: Shared.Domain.Events.SagaEvents.PaymentFailed,
          saga_id: command.saga_id,
          order_id: command.order_id,
          reason: reason,
          event_type: "payment.failed",
          occurred_at: DateTime.utc_now()
        }

        # イベントを発行
        event_topic = String.to_atom("events:#{event.event_type}")
        Shared.Infrastructure.EventBus.publish(event_topic, event)

        {:ok, %{success: false, event: event}}
    end
  end

  defp handle_arrange_shipping(command) do
    Logger.info("Arranging shipping for order: #{command.order_id}")

    # 配送手配のデモ実装
    case simulate_shipping_arrangement(command.order_id, command.user_id) do
      {:ok, shipping_id} ->
        # 配送手配成功イベントを発行
        event = %{
          __struct__: Shared.Domain.Events.SagaEvents.ShippingArranged,
          saga_id: command.saga_id,
          order_id: command.order_id,
          shipping_id: shipping_id,
          event_type: "shipping.arranged",
          occurred_at: DateTime.utc_now()
        }

        # イベントを発行
        event_topic = String.to_atom("events:#{event.event_type}")
        Shared.Infrastructure.EventBus.publish(event_topic, event)

        {:ok, %{success: true, event: event}}

      {:error, reason} ->
        # 配送手配失敗イベントを発行
        event = %{
          __struct__: Shared.Domain.Events.SagaEvents.ShippingArrangementFailed,
          saga_id: command.saga_id,
          order_id: command.order_id,
          reason: reason,
          event_type: "shipping.arrangement_failed",
          occurred_at: DateTime.utc_now()
        }

        # イベントを発行
        event_topic = String.to_atom("events:#{event.event_type}")
        Shared.Infrastructure.EventBus.publish(event_topic, event)

        {:ok, %{success: false, event: event}}
    end
  end

  defp handle_confirm_order(command) do
    Logger.info("Confirming order: #{command.order_id}")

    # 注文確定処理
    # 実際のアプリケーションでは、注文サービスのコマンドハンドラーを呼び出す
    event = %{
      __struct__: Shared.Domain.Events.SagaEvents.OrderConfirmed,
      saga_id: command.saga_id,
      order_id: command.order_id,
      event_type: "order.confirmed",
      occurred_at: DateTime.utc_now()
    }

    # イベントを発行
    event_topic = String.to_atom("events:#{event.event_type}")
    Shared.Infrastructure.EventBus.publish(event_topic, event)

    {:ok, %{success: true, event: event}}
  end

  defp handle_release_inventory(command) do
    Logger.info("Releasing inventory for order: #{command.order_id}")

    # 在庫解放処理
    event = %{
      __struct__: Shared.Domain.Events.SagaEvents.InventoryReleased,
      saga_id: command.saga_id,
      order_id: command.order_id,
      items: command.items,
      event_type: "inventory.released",
      occurred_at: DateTime.utc_now()
    }

    # イベントを発行
    event_topic = String.to_atom("events:#{event.event_type}")
    Shared.Infrastructure.EventBus.publish(event_topic, event)

    {:ok, %{success: true, event: event}}
  end

  defp handle_refund_payment(command) do
    Logger.info("Refunding payment for order: #{command.order_id}")

    # 返金処理
    event = %{
      __struct__: Shared.Domain.Events.SagaEvents.PaymentRefunded,
      saga_id: command.saga_id,
      order_id: command.order_id,
      amount: command.amount,
      event_type: "payment.refunded",
      occurred_at: DateTime.utc_now()
    }

    # イベントを発行
    event_topic = String.to_atom("events:#{event.event_type}")
    Shared.Infrastructure.EventBus.publish(event_topic, event)

    {:ok, %{success: true, event: event}}
  end

  defp handle_cancel_shipping(command) do
    Logger.info("Cancelling shipping for order: #{command.order_id}")

    # 配送キャンセル処理
    event = %{
      __struct__: Shared.Domain.Events.SagaEvents.ShippingCancelled,
      saga_id: command.saga_id,
      order_id: command.order_id,
      event_type: "shipping.cancelled",
      occurred_at: DateTime.utc_now()
    }

    # イベントを発行
    event_topic = String.to_atom("events:#{event.event_type}")
    Shared.Infrastructure.EventBus.publish(event_topic, event)

    {:ok, %{success: true, event: event}}
  end

  defp handle_cancel_order(command) do
    Logger.info("Cancelling order: #{command.order_id}")

    # 注文キャンセル処理
    event = %{
      __struct__: Shared.Domain.Events.SagaEvents.OrderCancelled,
      saga_id: command.saga_id,
      order_id: command.order_id,
      reason: command.reason,
      event_type: "order.cancelled",
      occurred_at: DateTime.utc_now()
    }

    # イベントを発行
    event_topic = String.to_atom("events:#{event.event_type}")
    Shared.Infrastructure.EventBus.publish(event_topic, event)

    {:ok, %{success: true, event: event}}
  end

  # シミュレーション関数

  defp simulate_inventory_check(_items) do
    # 80%の確率で成功
    if :rand.uniform() < 0.8 do
      {:ok, "Inventory reserved"}
    else
      {:error, "Insufficient inventory for some items"}
    end
  end

  defp simulate_payment_processing(amount, _user_id) do
    # 90%の確率で成功
    if :rand.uniform() < 0.9 do
      transaction_id = UUID.uuid4()
      {:ok, transaction_id}
    else
      {:error, "Payment declined"}
    end
  end

  defp simulate_shipping_arrangement(order_id, _user_id) do
    # 95%の確率で成功
    if :rand.uniform() < 0.95 do
      shipping_id = "SHIP-#{order_id}"
      {:ok, shipping_id}
    else
      {:error, "Shipping service unavailable"}
    end
  end
end

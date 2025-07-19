defmodule QueryService.Infrastructure.Projections.OrderProjection do
  @moduledoc """
  注文プロジェクション

  注文関連のイベントを処理し、Read Model を更新します
  """

  alias QueryService.Infrastructure.Repositories.OrderRepository
  alias QueryService.Infrastructure.Cache
  alias Shared.Domain.ValueObjects.EntityId

  alias Shared.Domain.Events.OrderEvents.{
    OrderCreated,
    OrderConfirmed,
    OrderPaymentProcessed,
    OrderCancelled,
    OrderItemReserved
  }

  alias Shared.Domain.Events.SagaEvents.{
    InventoryReserved,
    PaymentProcessed,
    ShippingArranged
  }

  alias Shared.Domain.Events.SagaEvents.OrderConfirmed, as: SagaOrderConfirmed

  require Logger

  @doc """
  イベントを処理する
  """
  def handle_event(%OrderCreated{} = event) do
    attrs = %{
      id: get_id_value(event.id),
      user_id: get_id_value(event.user_id),
      total_amount: Decimal.new(to_string(event.total_amount.amount)),
      currency: event.total_amount.currency,
      status: "pending",
      items: Enum.map(event.items, &transform_item/1),
      saga_id: if(Map.has_key?(event, :saga_id), do: get_id_value(event.saga_id), else: nil),
      saga_status: "started",
      saga_current_step: "reserve_inventory",
      created_at: event.created_at,
      updated_at: event.created_at
    }

    case OrderRepository.create(attrs) do
      {:ok, order} ->
        Logger.info("Order projection created: #{order.id}")
        # キャッシュを無効化
        Cache.delete_pattern("orders:*")
        {:ok, order}

      {:error, reason} ->
        Logger.error("Failed to create order projection: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_event(%OrderConfirmed{} = event) do
    attrs = %{
      status: "confirmed",
      confirmed_at: event.confirmed_at,
      updated_at: event.confirmed_at
    }

    update_order(get_id_value(event.id), attrs)
  end

  def handle_event(%OrderPaymentProcessed{} = event) do
    attrs = %{
      status: "payment_processed",
      payment_id: event.payment_id,
      payment_processed_at: event.processed_at,
      updated_at: event.processed_at
    }

    update_order(get_id_value(event.order_id), attrs)
  end

  def handle_event(%OrderCancelled{} = event) do
    attrs = %{
      status: "cancelled",
      cancellation_reason: event.reason,
      cancelled_at: event.cancelled_at,
      updated_at: event.cancelled_at
    }

    update_order(get_id_value(event.id), attrs)
  end

  def handle_event(%OrderItemReserved{} = event) do
    # 在庫予約イベント
    Logger.debug("Order item reserved: #{get_id_value(event.order_id)} - #{event.product_id}")
    :ok
  end

  # SAGA イベントのハンドラー
  def handle_event(%InventoryReserved{} = event) do
    attrs = %{
      status: "inventory_reserved",
      saga_current_step: "process_payment",
      updated_at: event.occurred_at
    }

    update_order(get_id_value(event.order_id), attrs)
  end

  def handle_event(%PaymentProcessed{} = event) do
    attrs = %{
      status: "payment_processed",
      payment_id: event.transaction_id,
      payment_processed_at: event.occurred_at,
      saga_current_step: "arrange_shipping",
      updated_at: event.occurred_at
    }

    update_order(get_id_value(event.order_id), attrs)
  end

  def handle_event(%ShippingArranged{} = event) do
    attrs = %{
      status: "shipped",
      shipping_id: event.shipping_id,
      shipped_at: event.occurred_at,
      saga_current_step: "confirm_order",
      updated_at: event.occurred_at
    }

    update_order(get_id_value(event.order_id), attrs)
  end

  def handle_event(%SagaOrderConfirmed{} = event) do
    attrs = %{
      status: "confirmed",
      confirmed_at: event.occurred_at,
      saga_status: "completed",
      saga_current_step: "completed",
      updated_at: event.occurred_at
    }

    update_order(get_id_value(event.order_id), attrs)
  end

  def handle_event(_event) do
    # 他のイベントは無視
    :ok
  end

  @doc """
  すべての注文プロジェクションをクリアする
  """
  def clear_all do
    case OrderRepository.delete_all() do
      {:ok, _} ->
        Logger.info("All order projections cleared")
        Cache.delete_pattern("orders:*")
        :ok

      {:error, reason} ->
        Logger.error("Failed to clear order projections: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private functions

  # ID の値を取得するヘルパー関数
  defp get_id_value(nil), do: nil
  defp get_id_value(%{value: value}), do: value
  defp get_id_value(value) when is_binary(value), do: value
  defp get_id_value(value), do: to_string(value)

  defp transform_item(item) do
    %{
      product_id: item.product_id,
      product_name: item.product_name,
      quantity: item.quantity,
      unit_price: Decimal.new(to_string(item.unit_price)),
      subtotal:
        Decimal.mult(
          Decimal.new(to_string(item.unit_price)),
          Decimal.new(to_string(item.quantity))
        )
    }
  end

  defp update_order(order_id, attrs) do
    case OrderRepository.update(order_id, attrs) do
      {:ok, order} ->
        Logger.info("Order projection updated: #{order.id}")
        # キャッシュを無効化
        Cache.delete("order:#{order.id}")
        Cache.delete_pattern("orders:*")
        {:ok, order}

      {:error, reason} ->
        Logger.error("Failed to update order projection: #{inspect(reason)}")
        {:error, reason}
    end
  end
end

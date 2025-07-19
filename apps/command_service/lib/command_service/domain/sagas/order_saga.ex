defmodule CommandService.Domain.Sagas.OrderSaga do
  @moduledoc """
  注文処理のSaga実装

  タイムアウト処理、詳細な監視、改善されたエラーハンドリングを含む。
  """

  @behaviour Shared.Infrastructure.Saga.SagaDefinition

  alias Shared.Domain.Events.OrderEvents.OrderCreated

  alias Shared.Domain.Events.SagaEvents.{
    InventoryReserved,
    InventoryReservationFailed,
    PaymentProcessed,
    PaymentFailed,
    ShippingArranged,
    ShippingArrangementFailed,
    OrderConfirmed
  }

  require Logger

  # タイムアウト設定（ミリ秒）
  # 30秒
  @inventory_timeout 30_000
  # 60秒
  @payment_timeout 60_000
  # 45秒
  @shipping_timeout 45_000
  # 10秒
  @confirmation_timeout 10_000

  @impl true
  def saga_name, do: "OrderSaga"

  @impl true
  def initial_state(%OrderCreated{} = event) do
    %{
      order_id: event.id.value,
      user_id: event.user_id.value,
      items:
        Enum.map(event.items, fn item ->
          %{
            product_id: item.product_id.value,
            quantity: item.quantity,
            price: item.price.amount
          }
        end),
      total_amount: event.total_amount.amount,
      shipping_address: event.shipping_address,
      # Saga固有の状態
      inventory_reserved: false,
      payment_processed: false,
      shipping_arranged: false,
      order_confirmed: false,
      # 補償処理のための情報
      reservation_ids: [],
      payment_transaction_id: nil,
      shipping_tracking_id: nil
    }
  end

  @impl true
  def steps do
    [
      %{
        name: :reserve_inventory,
        timeout: @inventory_timeout,
        compensate_on_timeout: true,
        retry_policy: %{
          max_attempts: 3,
          base_delay: 1_000,
          max_delay: 5_000,
          backoff_type: :exponential
        }
      },
      %{
        name: :process_payment,
        timeout: @payment_timeout,
        compensate_on_timeout: true,
        retry_policy: %{
          max_attempts: 2,
          base_delay: 2_000,
          max_delay: 10_000,
          backoff_type: :exponential
        }
      },
      %{
        name: :arrange_shipping,
        timeout: @shipping_timeout,
        compensate_on_timeout: true,
        retry_policy: %{
          max_attempts: 3,
          base_delay: 1_000,
          max_delay: 5_000,
          backoff_type: :linear
        }
      },
      %{
        name: :confirm_order,
        timeout: @confirmation_timeout,
        compensate_on_timeout: false,
        retry_policy: %{
          max_attempts: 5,
          base_delay: 500,
          max_delay: 2_000,
          backoff_type: :constant
        }
      }
    ]
  end

  @impl true
  def handle_event(%InventoryReserved{} = event, state) do
    if event.order_id == state.order_id do
      updated_state = %{
        state
        | inventory_reserved: true,
          reservation_ids: Enum.map(event.items, & &1.product_id)
      }

      {:ok, updated_state}
    else
      {:error, :not_my_event}
    end
  end

  def handle_event(%InventoryReservationFailed{} = event, state) do
    if event.order_id == state.order_id do
      # 在庫予約失敗の情報を記録
      updated_state = Map.put(state, :inventory_failure_reason, event.reason)
      {:ok, updated_state}
    else
      {:error, :not_my_event}
    end
  end

  def handle_event(%PaymentProcessed{} = event, state) do
    if event.order_id == state.order_id do
      updated_state = %{
        state
        | payment_processed: true,
          payment_transaction_id: event.transaction_id
      }

      {:ok, updated_state}
    else
      {:error, :not_my_event}
    end
  end

  def handle_event(%PaymentFailed{} = event, state) do
    if event.order_id == state.order_id do
      updated_state = Map.put(state, :payment_failure_reason, event.reason)
      {:ok, updated_state}
    else
      {:error, :not_my_event}
    end
  end

  def handle_event(%ShippingArranged{} = event, state) do
    if event.order_id == state.order_id do
      updated_state = %{
        state
        | shipping_arranged: true,
          shipping_tracking_id: event.tracking_id
      }

      {:ok, updated_state}
    else
      {:error, :not_my_event}
    end
  end

  def handle_event(%ShippingArrangementFailed{} = event, state) do
    if event.order_id == state.order_id do
      updated_state = Map.put(state, :shipping_failure_reason, event.reason)
      {:ok, updated_state}
    else
      {:error, :not_my_event}
    end
  end

  def handle_event(%OrderConfirmed{} = event, state) do
    if event.order_id == state.order_id do
      updated_state = Map.put(state, :order_confirmed, true)
      {:ok, updated_state}
    else
      {:error, :not_my_event}
    end
  end

  def handle_event(_event, _state) do
    {:error, :unknown_event}
  end

  @impl true
  def execute_step(:reserve_inventory, state) do
    Logger.info("Executing reserve_inventory for order #{state.order_id}")

    commands =
      Enum.map(state.items, fn item ->
        %{
          command_type: "ReserveStock",
          aggregate_id: item.product_id,
          order_id: state.order_id,
          quantity: item.quantity,
          saga_id: state.order_id,
          metadata: %{
            user_id: state.user_id,
            step: "reserve_inventory"
          }
        }
      end)

    {:ok, commands}
  end

  def execute_step(:process_payment, state) do
    Logger.info("Executing process_payment for order #{state.order_id}")

    command = %{
      command_type: "ProcessPayment",
      order_id: state.order_id,
      user_id: state.user_id,
      amount: state.total_amount,
      saga_id: state.order_id,
      metadata: %{
        step: "process_payment"
      }
    }

    {:ok, [command]}
  end

  def execute_step(:arrange_shipping, state) do
    Logger.info("Executing arrange_shipping for order #{state.order_id}")

    command = %{
      command_type: "ArrangeShipping",
      order_id: state.order_id,
      user_id: state.user_id,
      shipping_address: state.shipping_address,
      items: state.items,
      saga_id: state.order_id,
      metadata: %{
        step: "arrange_shipping"
      }
    }

    {:ok, [command]}
  end

  def execute_step(:confirm_order, state) do
    Logger.info("Executing confirm_order for order #{state.order_id}")

    command = %{
      command_type: "ConfirmOrder",
      aggregate_id: state.order_id,
      saga_id: state.order_id,
      metadata: %{
        step: "confirm_order",
        payment_transaction_id: state.payment_transaction_id,
        shipping_tracking_id: state.shipping_tracking_id
      }
    }

    {:ok, [command]}
  end

  @impl true
  def compensate_step(:reserve_inventory, state) do
    Logger.info("Compensating reserve_inventory for order #{state.order_id}")

    if state.inventory_reserved do
      commands =
        Enum.map(state.reservation_ids, fn product_id ->
          %{
            command_type: "ReleaseStock",
            aggregate_id: product_id,
            order_id: state.order_id,
            saga_id: state.order_id,
            metadata: %{
              compensation: true,
              step: "reserve_inventory"
            }
          }
        end)

      {:ok, commands}
    else
      {:ok, []}
    end
  end

  def compensate_step(:process_payment, state) do
    Logger.info("Compensating process_payment for order #{state.order_id}")

    if state.payment_processed && state.payment_transaction_id do
      command = %{
        command_type: "RefundPayment",
        order_id: state.order_id,
        transaction_id: state.payment_transaction_id,
        amount: state.total_amount,
        saga_id: state.order_id,
        metadata: %{
          compensation: true,
          step: "process_payment"
        }
      }

      {:ok, [command]}
    else
      {:ok, []}
    end
  end

  def compensate_step(:arrange_shipping, state) do
    Logger.info("Compensating arrange_shipping for order #{state.order_id}")

    if state.shipping_arranged && state.shipping_tracking_id do
      command = %{
        command_type: "CancelShipping",
        order_id: state.order_id,
        tracking_id: state.shipping_tracking_id,
        saga_id: state.order_id,
        metadata: %{
          compensation: true,
          step: "arrange_shipping"
        }
      }

      {:ok, [command]}
    else
      {:ok, []}
    end
  end

  def compensate_step(:confirm_order, state) do
    Logger.info("Compensating confirm_order for order #{state.order_id}")

    # 注文確定は補償不要（すでに失敗している）
    command = %{
      command_type: "CancelOrder",
      aggregate_id: state.order_id,
      saga_id: state.order_id,
      reason: state[:failure_reason] || "Saga failed",
      metadata: %{
        compensation: true,
        step: "confirm_order"
      }
    }

    {:ok, [command]}
  end

  @impl true
  def can_retry_step?(:reserve_inventory, error, _state) do
    case error do
      :insufficient_stock -> false
      :product_not_found -> false
      _ -> true
    end
  end

  def can_retry_step?(:process_payment, error, _state) do
    case error do
      :insufficient_funds -> false
      :invalid_payment_method -> false
      :fraud_detected -> false
      _ -> true
    end
  end

  def can_retry_step?(:arrange_shipping, error, _state) do
    case error do
      :invalid_address -> false
      :restricted_area -> false
      _ -> true
    end
  end

  def can_retry_step?(:confirm_order, _error, _state) do
    # 注文確定は常にリトライ可能
    true
  end

  @impl true
  def is_completed?(state) do
    state.order_confirmed == true
  end

  @impl true
  def is_failed?(state) do
    Map.has_key?(state, :inventory_failure_reason) ||
      Map.has_key?(state, :payment_failure_reason) ||
      Map.has_key?(state, :shipping_failure_reason)
  end

  @doc """
  各ステップで必要なリソースIDを返す（ロック順序制御のため）
  """
  def get_step_resources(:reserve_inventory, state) do
    # 在庫予約では商品IDをリソースとしてロック
    Enum.map(state.items, fn item -> "product:#{item.product_id}" end)
  end

  def get_step_resources(:process_payment, state) do
    # 支払い処理ではユーザーIDをリソースとしてロック
    ["user:#{state.user_id}"]
  end

  def get_step_resources(:arrange_shipping, state) do
    # 配送手配では注文IDをリソースとしてロック
    ["order:#{state.order_id}"]
  end

  def get_step_resources(:confirm_order, state) do
    # 注文確定では注文IDをリソースとしてロック
    ["order:#{state.order_id}"]
  end

  def get_step_resources(_, _), do: []
end

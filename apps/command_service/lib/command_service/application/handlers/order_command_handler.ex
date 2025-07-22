defmodule CommandService.Application.Handlers.OrderCommandHandler do
  @moduledoc """
  注文コマンドハンドラー
  """

  # Firestore への移行に伴い、IdempotentCommandHandler は一時的に削除
  # use Shared.Infrastructure.Idempotency.IdempotentCommandHandler

  alias CommandService.Application.Commands.OrderCommands
  alias CommandService.Domain.Aggregates.OrderAggregate
  alias CommandService.Infrastructure.{RepositoryContext, UnitOfWork}
  alias Shared.Infrastructure.EventBus
  alias Shared.Domain.Errors.{NotFoundError, ValidationError, BusinessRuleError}

  require Logger

  def handle(%OrderCommands.CreateOrder{} = command) do
    # TODO: 冪等性の処理を Firestore で実装
    UnitOfWork.transaction(fn ->
      case OrderAggregate.create(command.user_id, command.items) do
        {:ok, order} ->
          # イベントストアに保存
          {:ok, repo} = RepositoryContext.get_repository(:order)
          {:ok, _} = repo.save(order)

          # イベントを発行
          Enum.each(order.uncommitted_events, fn event ->
            EventBus.publish_event(event)
          end)

          # Sagaを開始（OrderCreatedイベントがトリガーとなる）
          # V2ではイベント駆動でSagaが開始されるため、明示的な開始は不要
          # OrderCreatedイベントは既に発行されている

          Logger.info("Order created, saga will be triggered by OrderCreated event")
          {:ok, %{order_id: order.id.value}}

        {:error, :invalid_items} ->
          {:error, ValidationError, %{field: "items", reason: "Invalid order items"}}

        {:error, :invalid_quantity} ->
          {:error, ValidationError,
           %{field: "quantity", reason: "Quantity must be greater than zero"}}

        {:error, reason} ->
          {:error, BusinessRuleError, %{rule: "order_creation", context: %{reason: reason}}}
      end
    end)
  end

  def handle(%OrderCommands.ConfirmOrder{} = command) do
    # TODO: 冪等性の処理を Firestore で実装
    UnitOfWork.transaction(fn ->
      {:ok, repo} = RepositoryContext.get_repository(:order)

      with {:ok, order} <- repo.find_by_id(command.order_id),
           {:ok, updated_order} <- OrderAggregate.confirm(order) do
        repo.save(updated_order)
        EventBus.publish_all(updated_order.uncommitted_events)

        {:ok, %{confirmed: true}}
      else
        {:error, :not_found} ->
          {:error, NotFoundError, %{resource: "Order", id: command.order_id}}

        {:error, :already_confirmed} ->
          {:error, BusinessRuleError,
           %{rule: "order_already_confirmed", context: %{order_id: command.order_id}}}

        {:error, reason} ->
          {:error, BusinessRuleError, %{rule: "order_confirmation", context: %{reason: reason}}}
      end
    end)
  end

  def handle(%OrderCommands.CancelOrder{} = command) do
    # TODO: 冪等性の処理を Firestore で実装
    UnitOfWork.transaction(fn ->
      {:ok, repo} = RepositoryContext.get_repository(:order)

      with {:ok, order} <- repo.find_by_id(command.order_id),
           {:ok, updated_order} <- OrderAggregate.cancel(order, command.reason) do
        repo.save(updated_order)
        EventBus.publish_all(updated_order.uncommitted_events)

        {:ok, %{cancelled: true}}
      else
        {:error, :not_found} ->
          {:error, NotFoundError, %{resource: "Order", id: command.order_id}}

        {:error, :already_cancelled} ->
          {:error, BusinessRuleError,
           %{rule: "order_already_cancelled", context: %{order_id: command.order_id}}}

        {:error, :cannot_cancel} ->
          {:error, BusinessRuleError,
           %{
             rule: "order_cannot_be_cancelled",
             context: %{order_id: command.order_id, reason: "Order is in final state"}
           }}

        {:error, reason} ->
          {:error, BusinessRuleError, %{rule: "order_cancellation", context: %{reason: reason}}}
      end
    end)
  end

  def handle(%OrderCommands.ReserveInventory{} = command) do
    UnitOfWork.transaction(fn ->
      {:ok, repo} = RepositoryContext.get_repository(:order)

      with {:ok, order} <- repo.find_by_id(command.order_id),
           {:ok, results} <- reserve_all_items(order, command.items, repo) do
        {:ok, %{reserved_items: results}}
      else
        {:error, :not_found} ->
          {:error, NotFoundError, %{resource: "Order", id: command.order_id}}

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end

  def handle(%OrderCommands.ProcessPayment{} = command) do
    UnitOfWork.transaction(fn ->
      {:ok, repo} = RepositoryContext.get_repository(:order)

      payment_id = UUID.uuid4()

      with {:ok, order} <- repo.find_by_id(command.order_id),
           {:ok, updated_order} <- OrderAggregate.process_payment(order, payment_id) do
        repo.save(updated_order)
        EventBus.publish_all(updated_order.uncommitted_events)

        {:ok, %{payment_processed: true, payment_id: payment_id}}
      else
        {:error, :not_found} ->
          {:error, NotFoundError, %{resource: "Order", id: command.order_id}}

        {:error, :payment_already_processed} ->
          {:error, BusinessRuleError,
           %{rule: "payment_already_processed", context: %{order_id: command.order_id}}}

        {:error, :invalid_order_state} ->
          {:error, BusinessRuleError,
           %{rule: "invalid_order_state_for_payment", context: %{order_id: command.order_id}}}

        {:error, reason} ->
          {:error, BusinessRuleError, %{rule: "payment_processing", context: %{reason: reason}}}
      end
    end)
  end

  def handle(%OrderCommands.ReleaseInventory{} = command) do
    Logger.info("Releasing inventory for order #{command.order_id}")

    # 実際の実装では ProductAggregate で在庫を戻す処理を行う
    event = %{
      event_type: "inventory_released",
      order_id: command.order_id,
      items: command.items,
      released_at: DateTime.utc_now()
    }

    EventBus.publish(event.event_type, event)
    {:ok, %{released: true}}
  end

  def handle(%OrderCommands.RefundPayment{} = command) do
    Logger.info("Refunding payment for order #{command.order_id}")

    # 実際の実装では決済サービスと連携して返金処理を行う
    event = %{
      event_type: "payment_refunded",
      order_id: command.order_id,
      amount: command.amount,
      refunded_at: DateTime.utc_now()
    }

    EventBus.publish(event.event_type, event)
    {:ok, %{refunded: true}}
  end

  def handle(%OrderCommands.CancelShipping{} = command) do
    Logger.info("Cancelling shipping for order #{command.order_id}")

    # 実際の実装では配送サービスと連携してキャンセル処理を行う
    event = %{
      event_type: "shipping_cancelled",
      order_id: command.order_id,
      cancelled_at: DateTime.utc_now()
    }

    EventBus.publish(event.event_type, event)
    {:ok, %{cancelled: true}}
  end

  def handle(command) do
    {:error, ValidationError,
     %{field: "command", reason: "Unknown order command: #{inspect(command.__struct__)}"}}
  end

  # Private functions

  defp reserve_all_items(order, items, repo) do
    results =
      Enum.map(items, fn item ->
        reserve_single_item(order, item, repo)
      end)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if Enum.empty?(errors) do
      {:ok, Enum.map(results, fn {:ok, id} -> id end)}
    else
      error_details =
        Enum.map(errors, fn {:error, {product_id, reason}} ->
          %{product_id: product_id, reason: to_string(reason)}
        end)

      {:error, ValidationError, %{errors: %{items: error_details}}}
    end
  end

  defp reserve_single_item(order, item, repo) do
    case OrderAggregate.reserve_item(order, item.product_id, item.quantity) do
      {:ok, updated_order} ->
        repo.save(updated_order)
        EventBus.publish_all(updated_order.uncommitted_events)
        {:ok, item.product_id}

      {:error, reason} ->
        {:error, {item.product_id, reason}}
    end
  end
end

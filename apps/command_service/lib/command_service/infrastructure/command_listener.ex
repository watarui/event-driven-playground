defmodule CommandService.Infrastructure.CommandListener do
  @moduledoc """
  コマンドリスナー

  PubSub からコマンドを受信し、CommandBus で処理してレスポンスを返します。
  """

  use GenServer

  alias Shared.Config
  alias CommandService.Infrastructure.CommandBus

  require Logger

  @command_topic :commands

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # コマンドトピックを購読（raw メソッドを使用）
    event_bus_module = Config.event_bus_module()
    event_bus_module.subscribe_raw(@command_topic)

    Logger.info(
      "CommandListener started and subscribed to commands using #{inspect(event_bus_module)}"
    )

    {:ok, %{event_bus: event_bus_module}}
  end

  @impl true
  def handle_info({:event, message}, state) when is_map(message) do
    Logger.info("CommandListener received command: #{inspect(message)}")

    # 非同期でコマンドを処理
    Task.start(fn ->
      process_command(message, state.event_bus)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # 通常のコマンド処理（client service からのコマンド）
  defp process_command(%{request_id: request_id, command: command, reply_to: reply_to}, event_bus) do
    Logger.info(
      "Processing command: request_id=#{request_id}, type=#{inspect(command[:command_type])}, reply_to=#{reply_to}"
    )

    Logger.debug("Full command data: #{inspect(command)}")

    # コマンドバリデーションと変換
    validated_command = validate_and_convert_command(command)

    # コマンドを実行
    result =
      case validated_command do
        {:ok, cmd} -> CommandBus.dispatch(cmd)
        error -> error
      end

    # レスポンスを作成
    response = %{
      request_id: request_id,
      result: result,
      timestamp: DateTime.utc_now()
    }

    # レスポンスを返信（raw メソッドを使用）
    event_bus.publish_raw(reply_to, response)
  rescue
    error ->
      Logger.error("Error processing command: #{inspect(error)}")

      # エラーレスポンスを返信
      response = %{
        request_id: request_id,
        result: {:error, "Command processing failed: #{inspect(error)}"},
        timestamp: DateTime.utc_now()
      }

      event_bus.publish_raw(reply_to, response)
  end

  # SAGA からのコマンド処理（reply_to がない）
  defp process_command(command_map, _event_bus) when is_map(command_map) do
    Logger.info("Processing SAGA command: #{inspect(command_map)}")

    # コマンドバリデーションと変換
    validated_command = validate_and_convert_command(command_map)

    # コマンドを非同期実行
    case validated_command do
      {:ok, cmd} ->
        CommandBus.dispatch_async(cmd)

      error ->
        Logger.error("Failed to validate SAGA command: #{inspect(error)}")
    end
  end

  defp validate_and_convert_command(command_map) do
    case command_map[:command_type] do
      "category.create" ->
        CommandService.Application.Commands.CategoryCommands.CreateCategory.validate(%{
          name: command_map[:name],
          description: command_map[:description],
          metadata: command_map[:metadata] || %{}
        })

      "category.update" ->
        CommandService.Application.Commands.CategoryCommands.UpdateCategory.validate(%{
          id: command_map[:id],
          name: command_map[:name],
          description: command_map[:description],
          metadata: command_map[:metadata] || %{}
        })

      "category.delete" ->
        CommandService.Application.Commands.CategoryCommands.DeleteCategory.validate(%{
          id: command_map[:id],
          metadata: command_map[:metadata] || %{}
        })

      "product.create" ->
        CommandService.Application.Commands.ProductCommands.CreateProduct.validate(%{
          name: command_map[:name],
          price: command_map[:price],
          category_id: command_map[:category_id],
          stock_quantity: command_map[:stock_quantity],
          description: command_map[:description],
          metadata: command_map[:metadata] || %{}
        })

      "product.update" ->
        CommandService.Application.Commands.ProductCommands.UpdateProduct.validate(%{
          id: command_map[:id],
          name: command_map[:name],
          price: command_map[:price],
          category_id: command_map[:category_id],
          metadata: command_map[:metadata] || %{}
        })

      "product.delete" ->
        CommandService.Application.Commands.ProductCommands.DeleteProduct.validate(%{
          id: command_map[:id],
          metadata: command_map[:metadata] || %{}
        })

      "product.change_price" ->
        CommandService.Application.Commands.ProductCommands.ChangeProductPrice.validate(%{
          id: command_map[:id],
          new_price: command_map[:new_price],
          metadata: command_map[:metadata] || %{}
        })

      "product.update_stock" ->
        CommandService.Application.Commands.ProductCommands.UpdateStock.validate(%{
          product_id: command_map[:product_id],
          quantity: command_map[:quantity],
          metadata: command_map[:metadata] || %{}
        })

      "order.create" ->
        Logger.debug("order.create command_map: #{inspect(command_map)}")

        CommandService.Application.Commands.OrderCommands.CreateOrder.new(%{
          user_id: command_map[:user_id],
          items: command_map[:items],
          shipping_address: command_map[:shipping_address],
          metadata: command_map[:metadata]
        })

      "order.confirm" ->
        cmd =
          CommandService.Application.Commands.SagaCommands.ConfirmOrder.new(%{
            saga_id: command_map[:saga_id],
            order_id: command_map[:order_id],
            metadata: command_map[:metadata]
          })

        CommandService.Application.Commands.SagaCommands.ConfirmOrder.validate(cmd)

      "order.cancel" ->
        cmd =
          CommandService.Application.Commands.SagaCommands.CancelOrder.new(%{
            saga_id: command_map[:saga_id],
            order_id: command_map[:order_id],
            reason: command_map[:reason],
            metadata: command_map[:metadata]
          })

        CommandService.Application.Commands.SagaCommands.CancelOrder.validate(cmd)

      # Saga commands
      "reserve_inventory" ->
        Logger.debug("reserve_inventory command_map: #{inspect(command_map)}")
        # items がない場合は、product_id と quantity から生成
        items =
          command_map[:items] ||
            [
              %{
                product_id: command_map[:product_id],
                quantity: command_map[:quantity]
              }
            ]

        cmd =
          CommandService.Application.Commands.SagaCommands.ReserveInventory.new(%{
            saga_id: command_map[:saga_id],
            order_id: command_map[:order_id],
            items: items
          })

        CommandService.Application.Commands.SagaCommands.ReserveInventory.validate(cmd)

      "process_payment" ->
        Logger.debug("process_payment command_map: #{inspect(command_map)}")

        cmd =
          CommandService.Application.Commands.SagaCommands.ProcessPayment.new(%{
            saga_id: command_map[:saga_id],
            order_id: command_map[:order_id],
            amount: command_map[:amount],
            user_id: command_map[:user_id]
          })

        CommandService.Application.Commands.SagaCommands.ProcessPayment.validate(cmd)

      "arrange_shipping" ->
        Logger.debug("arrange_shipping command_map: #{inspect(command_map)}")

        cmd =
          CommandService.Application.Commands.SagaCommands.ArrangeShipping.new(%{
            saga_id: command_map[:saga_id],
            order_id: command_map[:order_id],
            user_id: command_map[:user_id]
          })

        CommandService.Application.Commands.SagaCommands.ArrangeShipping.validate(cmd)

      "confirm_order" ->
        Logger.debug("confirm_order command_map: #{inspect(command_map)}")

        cmd =
          CommandService.Application.Commands.SagaCommands.ConfirmOrder.new(%{
            saga_id: command_map[:saga_id],
            order_id: command_map[:order_id]
          })

        CommandService.Application.Commands.SagaCommands.ConfirmOrder.validate(cmd)

      "release_inventory" ->
        Logger.debug("release_inventory command_map: #{inspect(command_map)}")

        cmd =
          CommandService.Application.Commands.SagaCommands.ReleaseInventory.new(%{
            saga_id: command_map[:saga_id],
            order_id: command_map[:order_id],
            items: command_map[:items]
          })

        CommandService.Application.Commands.SagaCommands.ReleaseInventory.validate(cmd)

      "refund_payment" ->
        Logger.debug("refund_payment command_map: #{inspect(command_map)}")

        cmd =
          CommandService.Application.Commands.SagaCommands.RefundPayment.new(%{
            saga_id: command_map[:saga_id],
            order_id: command_map[:order_id],
            amount: command_map[:amount]
          })

        CommandService.Application.Commands.SagaCommands.RefundPayment.validate(cmd)

      "cancel_shipping" ->
        Logger.debug("cancel_shipping command_map: #{inspect(command_map)}")

        cmd =
          CommandService.Application.Commands.SagaCommands.CancelShipping.new(%{
            saga_id: command_map[:saga_id],
            order_id: command_map[:order_id]
          })

        CommandService.Application.Commands.SagaCommands.CancelShipping.validate(cmd)

      "cancel_order" ->
        Logger.debug("cancel_order command_map: #{inspect(command_map)}")

        cmd =
          CommandService.Application.Commands.SagaCommands.CancelOrder.new(%{
            saga_id: command_map[:saga_id],
            order_id: command_map[:order_id],
            reason: command_map[:reason]
          })

        CommandService.Application.Commands.SagaCommands.CancelOrder.validate(cmd)

      type ->
        {:error, "Unknown command type: #{type}"}
    end
  end
end

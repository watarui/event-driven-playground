defmodule Shared.Infrastructure.Saga.CommandDispatcher do
  @moduledoc """
  サガコマンドディスパッチャー

  サガから発行されたコマンドを適切なコマンドサービスに送信します
  """

  @behaviour Shared.Domain.Saga.CommandDispatcherBehaviour

  alias Shared.Config

  require Logger

  @impl true
  def dispatch_command(command) do
    Logger.info("Dispatching command: #{inspect(command)}")

    try do
      case command.command_type do
        type
        when type in [
               "reserve_inventory",
               "process_payment",
               "arrange_shipping",
               "confirm_order",
               "release_inventory",
               "refund_payment",
               "cancel_shipping",
               "cancel_order"
             ] ->
          # EventBus 経由でコマンドサービスに送信
          event_bus = Config.event_bus_module()
          event_bus.publish_raw(:commands, command)

          {:ok, %{dispatched: true}}

        _ ->
          {:error, "Unknown command type: #{command.command_type}"}
      end
    rescue
      e ->
        Logger.error("Failed to dispatch command: #{inspect(e)}")
        {:error, "Failed to dispatch command"}
    end
  end

  @impl true
  def dispatch_commands(commands) when is_list(commands) do
    results = Enum.map(commands, &dispatch_command/1)

    errors =
      Enum.filter(results, fn
        {:error, _} -> true
        _ -> false
      end)

    if Enum.empty?(errors) do
      {:ok, %{all_dispatched: true}}
    else
      {:error, "Some commands failed to dispatch: #{inspect(errors)}"}
    end
  end
end

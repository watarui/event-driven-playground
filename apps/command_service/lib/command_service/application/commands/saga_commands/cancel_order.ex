defmodule CommandService.Application.Commands.SagaCommands.CancelOrder do
  @moduledoc """
  注文キャンセルコマンド
  """

  use CommandService.Application.Commands.BaseCommand

  defstruct [:saga_id, :order_id, :reason, :metadata]

  @type t :: %__MODULE__{
          saga_id: String.t(),
          order_id: String.t(),
          reason: String.t(),
          metadata: map()
        }

  def new(params) do
    %__MODULE__{
      saga_id: params[:saga_id],
      order_id: params[:order_id],
      reason: params[:reason],
      metadata: params[:metadata] || %{}
    }
  end

  def validate(command) do
    with :ok <- validate_required(command.saga_id, "saga_id"),
         :ok <- validate_required(command.order_id, "order_id"),
         :ok <- validate_required(command.reason, "reason") do
      {:ok, command}
    end
  end

  def command_type, do: "cancel_order"
end

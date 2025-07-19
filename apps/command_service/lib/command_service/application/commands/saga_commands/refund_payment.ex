defmodule CommandService.Application.Commands.SagaCommands.RefundPayment do
  @moduledoc """
  返金処理コマンド
  """

  use CommandService.Application.Commands.BaseCommand

  defstruct [:saga_id, :order_id, :amount, :metadata]

  @type t :: %__MODULE__{
          saga_id: String.t(),
          order_id: String.t(),
          amount: Decimal.t() | float() | integer(),
          metadata: map()
        }

  def new(params) do
    %__MODULE__{
      saga_id: params[:saga_id],
      order_id: params[:order_id],
      amount: params[:amount],
      metadata: params[:metadata] || %{}
    }
  end

  def validate(command) do
    with :ok <- validate_required(command.saga_id, "saga_id"),
         :ok <- validate_required(command.order_id, "order_id"),
         :ok <- validate_required(command.amount, "amount"),
         :ok <- validate_positive_number(command.amount, "amount") do
      {:ok, command}
    end
  end

  def command_type, do: "refund_payment"
end

defmodule CommandService.Application.Commands.SagaCommands.ProcessPayment do
  @moduledoc """
  支払い処理コマンド
  """

  use CommandService.Application.Commands.BaseCommand

  defstruct [:saga_id, :order_id, :amount, :user_id, :metadata]

  @type t :: %__MODULE__{
          saga_id: String.t(),
          order_id: String.t(),
          amount: Decimal.t() | float() | integer(),
          user_id: String.t(),
          metadata: map()
        }

  def new(params) do
    %__MODULE__{
      saga_id: params[:saga_id],
      order_id: params[:order_id],
      amount: params[:amount],
      user_id: params[:user_id],
      metadata: params[:metadata] || %{}
    }
  end

  def validate(command) do
    with :ok <- validate_required(command.saga_id, "saga_id"),
         :ok <- validate_required(command.order_id, "order_id"),
         :ok <- validate_required(command.amount, "amount"),
         :ok <- validate_positive_number(command.amount, "amount"),
         :ok <- validate_required(command.user_id, "user_id") do
      {:ok, command}
    end
  end

  def command_type, do: "process_payment"
end

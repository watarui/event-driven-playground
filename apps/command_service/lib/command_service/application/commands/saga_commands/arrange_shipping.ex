defmodule CommandService.Application.Commands.SagaCommands.ArrangeShipping do
  @moduledoc """
  配送手配コマンド
  """

  use CommandService.Application.Commands.BaseCommand

  defstruct [:saga_id, :order_id, :user_id, :metadata]

  @type t :: %__MODULE__{
          saga_id: String.t(),
          order_id: String.t(),
          user_id: String.t(),
          metadata: map()
        }

  def new(params) do
    %__MODULE__{
      saga_id: params[:saga_id],
      order_id: params[:order_id],
      user_id: params[:user_id],
      metadata: params[:metadata] || %{}
    }
  end

  def validate(command) do
    with :ok <- validate_required(command.saga_id, "saga_id"),
         :ok <- validate_required(command.order_id, "order_id"),
         :ok <- validate_required(command.user_id, "user_id") do
      {:ok, command}
    end
  end

  def command_type, do: "arrange_shipping"
end

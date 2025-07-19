defmodule Shared.Domain.Saga.Step do
  @moduledoc """
  SAGA のステップを表す構造体
  """

  @type t :: %__MODULE__{
          name: atom(),
          handler: function(),
          compensation: function() | nil,
          timeout: non_neg_integer()
        }

  defstruct [:name, :handler, :compensation, timeout: 30_000]
end

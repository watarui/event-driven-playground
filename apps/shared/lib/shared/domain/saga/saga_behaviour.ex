defmodule Shared.Domain.Saga.SagaBehaviour do
  @moduledoc """
  SAGA の振る舞いを定義するビヘイビア
  """

  @type saga_id :: String.t()
  @type saga_data :: map()
  @type event :: any()
  @type step_result :: {:ok, saga_data} | {:error, any()}
  @type event_result ::
          {:continue, saga_data} | {:complete, saga_data} | {:compensate, String.t()}

  @doc """
  SAGA のステップを定義
  """
  @callback steps() :: [Shared.Domain.Saga.Step.t()]

  @doc """
  イベントを処理
  """
  @callback handle_event(saga_id, event, saga_data) :: event_result
end

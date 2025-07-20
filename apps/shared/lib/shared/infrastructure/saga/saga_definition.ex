defmodule Shared.Infrastructure.Saga.SagaDefinition do
  @moduledoc """
  Sagaの定義を表すビヘイビア

  各Sagaはこのビヘイビアを実装し、ステップの定義、タイムアウト設定、
  補償処理などを宣言的に記述する。
  """

  @type saga_id :: String.t()
  @type step_name :: atom()
  @type saga_state :: map()
  @type command :: map()
  @type event :: struct()
  @type error_reason :: any()

  @type step_result :: {:ok, [command()]} | {:error, error_reason()}
  @type compensation_result :: {:ok, [command()]} | {:error, error_reason()}

  @type step_definition :: %{
          name: step_name(),
          timeout: non_neg_integer(),
          compensate_on_timeout: boolean(),
          retry_policy: map() | nil
        }

  @callback saga_name() :: String.t()
  @callback initial_state(event()) :: saga_state()
  @callback steps() :: [step_definition()]
  @callback handle_event(event(), saga_state()) :: {:ok, saga_state()} | {:error, error_reason()}
  @callback execute_step(step_name(), saga_state()) :: step_result()
  @callback compensate_step(step_name(), saga_state()) :: compensation_result()
  @callback can_retry_step?(step_name(), error_reason(), saga_state()) :: boolean()
  @callback is_completed?(saga_state()) :: boolean()
  @callback is_failed?(saga_state()) :: boolean()

  @doc """
  Sagaの各ステップのタイムアウト設定を取得
  """
  @spec get_step_timeout(module(), step_name()) :: non_neg_integer() | nil
  def get_step_timeout(saga_module, step_name) do
    saga_module.steps()
    |> Enum.find(fn step -> step.name == step_name end)
    |> case do
      nil -> nil
      step -> step.timeout
    end
  end

  @doc """
  タイムアウト時に補償処理を実行するかどうか
  """
  @spec compensate_on_timeout?(module(), step_name()) :: boolean()
  def compensate_on_timeout?(saga_module, step_name) do
    saga_module.steps()
    |> Enum.find(fn step -> step.name == step_name end)
    |> case do
      nil -> false
      step -> Map.get(step, :compensate_on_timeout, true)
    end
  end

  @doc """
  ステップのリトライポリシーを取得
  """
  @spec get_retry_policy(module(), step_name()) :: map() | nil
  def get_retry_policy(saga_module, step_name) do
    saga_module.steps()
    |> Enum.find(fn step -> step.name == step_name end)
    |> case do
      nil -> nil
      step -> Map.get(step, :retry_policy)
    end
  end

  @doc """
  次のステップを取得
  """
  @spec get_next_step(module(), saga_state()) :: step_name() | nil
  def get_next_step(saga_module, saga_state) do
    steps = saga_module.steps()

    # 現在のステップまたは最後に完了したステップを基準にする
    current_step = saga_state[:current_step] || List.last(saga_state[:completed_steps] || [])

    if current_step do
      current_index = Enum.find_index(steps, fn step -> step.name == current_step end)

      if current_index && current_index < length(steps) - 1 do
        Enum.at(steps, current_index + 1).name
      else
        nil
      end
    else
      # 初回実行時は最初のステップを返す
      case steps do
        [first_step | _] -> first_step.name
        [] -> nil
      end
    end
  end

  @doc """
  前のステップを取得（補償処理用）
  """
  @spec get_previous_step(module(), step_name()) :: step_name() | nil
  def get_previous_step(saga_module, current_step) do
    steps = saga_module.steps()
    current_index = Enum.find_index(steps, fn step -> step.name == current_step end)

    if current_index && current_index > 0 do
      Enum.at(steps, current_index - 1).name
    else
      nil
    end
  end
end

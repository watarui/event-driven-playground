defmodule Shared.Infrastructure.Saga.SagaSimpleTest do
  use ExUnit.Case, async: false

  alias Shared.Infrastructure.Saga.SagaExecutor
  alias Shared.Infrastructure.EventBus

  # シンプルなテスト用の Saga モジュール
  defmodule SimpleSaga do
    use Shared.Infrastructure.Saga.SagaDefinition

    @impl true
    def saga_name, do: "SimpleSaga"

    @impl true
    def initial_state(event) do
      %{
        test_id: Map.get(event, :test_id, "test-123"),
        completed: false
      }
    end

    @impl true
    def steps do
      [
        %{
          name: :simple_step,
          timeout: 5000,
          compensate_on_timeout: false,
          retry_policy: nil
        }
      ]
    end

    @impl true
    def handle_event(%{event_type: :step_completed}, state) do
      {:ok, %{state | completed: true}}
    end

    def handle_event(_, _state) do
      :ignore
    end

    @impl true
    def execute_step(:simple_step, state) do
      commands = [
        %{
          command_type: "SimpleCommand",
          test_id: state.test_id
        }
      ]

      {:ok, commands}
    end

    @impl true
    def compensate_step(:simple_step, _state) do
      {:ok, []}
    end

    @impl true
    def can_retry_step?(_, _, _), do: false

    @impl true
    def is_completed?(state) do
      state.completed == true
    end

    @impl true
    def is_failed?(_state) do
      false
    end
  end

  setup do
    # EventBus が起動していない場合のみ開始
    case Process.whereis(EventBus) do
      nil -> start_supervised!(EventBus)
      _pid -> :ok
    end

    # SagaExecutor を開始
    {:ok, _executor} = start_supervised(SagaExecutor)

    :ok
  end

  test "新しい Saga を開始できる" do
    trigger_event = %{test_id: "test-start", event_type: :test_created}

    assert {:ok, saga_id} = SagaExecutor.start_saga(SimpleSaga, trigger_event)
    assert saga_id =~ "SimpleSaga:"

    # Saga の状態を確認
    assert {:ok, saga_state} = SagaExecutor.get_saga_state(saga_id)
    assert saga_state.saga_name == "SimpleSaga"
    assert saga_state.status == :running
  end

  test "アクティブな Saga のリストを取得できる" do
    # Saga を開始
    trigger_event = %{test_id: "test-list", event_type: :test_created}
    {:ok, saga_id} = SagaExecutor.start_saga(SimpleSaga, trigger_event)

    # アクティブな Saga を取得
    {:ok, active_sagas} = SagaExecutor.list_active_sagas()

    assert Enum.any?(active_sagas, fn saga ->
             saga.saga_id == saga_id && saga.saga_name == "SimpleSaga"
           end)
  end

  test "Saga を強制終了できる" do
    trigger_event = %{test_id: "test-terminate", event_type: :test_created}
    {:ok, saga_id} = SagaExecutor.start_saga(SimpleSaga, trigger_event)

    # Saga を終了
    assert :ok = SagaExecutor.terminate_saga(saga_id)

    # 終了後はアクティブリストに含まれない
    {:ok, active_sagas} = SagaExecutor.list_active_sagas()
    refute Enum.any?(active_sagas, fn saga -> saga.saga_id == saga_id end)
  end
end

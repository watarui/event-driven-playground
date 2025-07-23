defmodule Shared.Infrastructure.Saga.SagaExecutorTest do
  use ExUnit.Case, async: false

  alias Shared.Infrastructure.Saga.{SagaExecutor, SagaRepository}
  alias Shared.Infrastructure.EventBus

  # テスト用の Saga モジュール
  defmodule TestSaga do
    @behaviour Shared.Behaviours.Saga

    @impl true
    def saga_name, do: "TestSaga"

    @impl true
    def initial_state(event) do
      %{
        test_id: event.test_id,
        step1_completed: false,
        step2_completed: false,
        compensated: false
      }
    end

    @impl true
    def steps do
      [
        %{
          name: :step1,
          timeout: 5000,
          compensate_on_timeout: true,
          retry_policy: %{
            max_attempts: 2,
            base_delay: 100,
            max_delay: 500,
            backoff_type: :exponential
          }
        },
        %{
          name: :step2,
          timeout: 5000,
          compensate_on_timeout: true,
          retry_policy: nil
        }
      ]
    end

    @impl true
    def handle_event(%{event_type: :step1_completed}, state) do
      {:ok, %{state | step1_completed: true}}
    end

    def handle_event(%{event_type: :step2_completed}, state) do
      {:ok, %{state | step2_completed: true}}
    end

    def handle_event(_, _state) do
      :ignore
    end

    @impl true
    def execute_step(:step1, state) do
      commands = [
        %{
          command_type: "TestCommand1",
          test_id: state.test_id,
          saga_id: "TestSaga:#{state.test_id}"
        }
      ]

      {:ok, commands}
    end

    def execute_step(:step2, state) do
      commands = [
        %{
          command_type: "TestCommand2",
          test_id: state.test_id,
          saga_id: "TestSaga:#{state.test_id}"
        }
      ]

      {:ok, commands}
    end

    @impl true
    def compensate_step(:step1, _state) do
      commands = [
        %{
          command_type: "CompensateCommand1",
          compensation: true
        }
      ]

      {:ok, commands}
    end

    def compensate_step(:step2, _state) do
      {:ok, []}
    end

    @impl true
    def can_retry_step?(:step1, :transient_error, _state), do: true
    def can_retry_step?(_, _, _), do: false

    @impl true
    def is_completed?(state) do
      state.step1_completed && state.step2_completed
    end

    @impl true
    def is_failed?(state) do
      Map.get(state, :failed, false)
    end
  end

  setup do
    # EventBus が起動していない場合のみ開始
    case Process.whereis(EventBus) do
      nil -> start_supervised!(EventBus)
      _pid -> :ok
    end

    # SagaExecutor を開始
    {:ok, executor} = start_supervised(SagaExecutor)

    # テスト用のイベントバスサブスクリプション
    :ok = EventBus.subscribe("saga_events")

    {:ok, executor: executor}
  end

  describe "start_saga/2" do
    test "新しい Saga を開始できる" do
      trigger_event = %{
        __struct__: TestEvent,
        test_id: "test-123",
        event_type: :test_created
      }

      assert {:ok, saga_id} = SagaExecutor.start_saga(TestSaga, trigger_event)
      assert saga_id == "TestSaga:test-123"

      # Saga の状態を確認
      assert {:ok, saga_state} = SagaExecutor.get_saga_state(saga_id)
      assert saga_state.saga_name == "TestSaga"
      assert saga_state.status == :running
    end

    test "同じ Saga を二重に開始できない" do
      trigger_event = %{
        __struct__: TestEvent,
        test_id: "test-456",
        event_type: :test_created
      }

      assert {:ok, saga_id} = SagaExecutor.start_saga(TestSaga, trigger_event)
      assert {:error, :saga_already_running} = SagaExecutor.start_saga(TestSaga, trigger_event)
    end
  end

  describe "handle_event/1" do
    test "イベントを既存の Saga にルーティングできる" do
      # Saga を開始
      trigger_event = %{
        __struct__: TestEvent,
        test_id: "test-789",
        event_type: :test_created
      }

      {:ok, saga_id} = SagaExecutor.start_saga(TestSaga, trigger_event)

      # ステップ完了イベントを送信
      event = %{
        event_type: :step1_completed,
        saga_id: saga_id
      }

      assert :ok = SagaExecutor.handle_event(event)

      # 少し待つ
      Process.sleep(100)

      # Saga の状態を確認
      {:ok, saga_state} = SagaExecutor.get_saga_state(saga_id)
      assert saga_state.saga_state.step1_completed == true
    end
  end

  describe "list_active_sagas/0" do
    test "アクティブな Saga のリストを取得できる" do
      # 複数の Saga を開始
      for i <- 1..3 do
        trigger_event = %{
          __struct__: TestEvent,
          test_id: "test-list-#{i}",
          event_type: :test_created
        }

        {:ok, _} = SagaExecutor.start_saga(TestSaga, trigger_event)
      end

      # アクティブな Saga を取得
      {:ok, active_sagas} = SagaExecutor.list_active_sagas()

      assert length(active_sagas) >= 3

      assert Enum.all?(active_sagas, fn saga ->
               saga.saga_name == "TestSaga" && saga.status == :running
             end)
    end
  end

  describe "terminate_saga/2" do
    test "Saga を強制終了できる" do
      trigger_event = %{
        __struct__: TestEvent,
        test_id: "test-terminate",
        event_type: :test_created
      }

      {:ok, saga_id} = SagaExecutor.start_saga(TestSaga, trigger_event)

      # Saga を終了
      assert :ok = SagaExecutor.terminate_saga(saga_id, :manual_termination)

      # 終了後はアクティブリストに含まれない
      {:ok, active_sagas} = SagaExecutor.list_active_sagas()
      refute Enum.any?(active_sagas, fn saga -> saga.saga_id == saga_id end)
    end

    test "存在しない Saga の終了はエラーを返す" do
      assert {:error, :saga_not_found} = SagaExecutor.terminate_saga("non-existent", :test)
    end
  end

  describe "saga completion" do
    test "全ステップ完了後に Saga が完了する" do
      trigger_event = %{
        __struct__: TestEvent,
        test_id: "test-complete",
        event_type: :test_created
      }

      {:ok, saga_id} = SagaExecutor.start_saga(TestSaga, trigger_event)

      # ステップ1完了
      SagaExecutor.handle_event(%{
        event_type: :step1_completed,
        saga_id: saga_id
      })

      Process.sleep(100)

      # ステップ2完了
      SagaExecutor.handle_event(%{
        event_type: :step2_completed,
        saga_id: saga_id
      })

      # 完了イベントを待つ
      assert_receive {:saga_completed, ^saga_id}, 1000

      # DBから状態を確認
      {:ok, saga_data} = SagaRepository.get_saga(saga_id)
      assert saga_data.status == "completed"
    end
  end

  describe "saga timeout" do
    test "タイムアウト時に補償処理が実行される" do
      # タイムアウトの短い Saga
      defmodule TimeoutTestSaga do
        @behaviour Shared.Behaviours.Saga

        def saga_name, do: "TimeoutTestSaga"

        def initial_state(event) do
          %{test_id: event.test_id, compensated: false}
        end

        def steps do
          [
            %{
              name: :slow_step,
              # 100ms でタイムアウト
              timeout: 100,
              compensate_on_timeout: true,
              retry_policy: nil
            }
          ]
        end

        def handle_event(_, state), do: {:ok, state}

        def execute_step(:slow_step, state) do
          # このステップは完了しない
          {:ok, [%{command_type: "SlowCommand", test_id: state.test_id}]}
        end

        def compensate_step(:slow_step, _state) do
          {:ok, [%{command_type: "CompensateSlowCommand", compensation: true}]}
        end

        def can_retry_step?(_, _, _), do: false
        def is_completed?(_), do: false
        def is_failed?(state), do: Map.get(state, :failed, false)
      end

      trigger_event = %{
        __struct__: TestEvent,
        test_id: "test-timeout",
        event_type: :test_created
      }

      {:ok, saga_id} = SagaExecutor.start_saga(TimeoutTestSaga, trigger_event)

      # タイムアウトと補償処理を待つ
      Process.sleep(300)

      # Saga が失敗していることを確認
      {:ok, saga_data} = SagaRepository.get_saga(saga_id)
      assert saga_data.status == "failed"
    end
  end

  # テスト用のダミーイベント構造体
  defmodule TestEvent do
    defstruct [:test_id, :event_type]
  end
end

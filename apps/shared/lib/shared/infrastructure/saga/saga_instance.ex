defmodule Shared.Infrastructure.Saga.SagaInstance do
  @moduledoc """
  個別の Saga インスタンスを管理する GenStateMachine

  Saga の状態遷移、ステップ実行、補償処理を管理します。
  """

  use GenStateMachine, callback_mode: :state_functions
  require Logger

  alias Shared.Infrastructure.Saga.SagaRepository
  alias Shared.Infrastructure.EventBus

  # State data の構造
  defmodule Data do
    @moduledoc false
    defstruct [
      :saga_id,
      :saga_module,
      :saga_state,
      :current_step,
      :current_step_index,
      :steps,
      # :running, :compensating, :completed, :failed
      :status,
      :failure_reason,
      :retry_count,
      :started_at,
      :updated_at,
      # SagaExecutor の PID
      :executor_pid,
      :step_started_at,
      :compensation_index
    ]
  end

  # Public API

  @doc """
  新しい Saga インスタンスを開始
  """
  def start_link(saga_id, saga_module, trigger_event, executor_pid) do
    GenStateMachine.start_link(__MODULE__, {saga_id, saga_module, trigger_event, executor_pid})
  end

  @doc """
  既存の Saga インスタンスを復元
  """
  def restore(saga_data, saga_module, executor_pid) do
    GenStateMachine.start_link(__MODULE__, {:restore, saga_data, saga_module, executor_pid})
  end

  @doc """
  イベントを処理
  """
  def handle_event(pid, event) do
    GenStateMachine.call(pid, {:handle_event, event})
  end

  @doc """
  タイムアウトを処理
  """
  def handle_timeout(pid, step_name) do
    GenStateMachine.call(pid, {:handle_timeout, step_name})
  end

  @doc """
  現在の状態を取得
  """
  def get_state(pid) do
    GenStateMachine.call(pid, :get_state)
  end

  @doc """
  Saga を停止
  """
  def stop(pid, reason \\ :normal) do
    GenStateMachine.stop(pid, reason)
  end

  # GenStateMachine Callbacks

  @impl true
  def init(args) do
    case args do
      {saga_id, saga_module, trigger_event, executor_pid} ->
        # 新規 Saga の初期化
        initial_saga_state = saga_module.initial_state(trigger_event)
        steps = saga_module.steps()

        data = %Data{
          saga_id: saga_id,
          saga_module: saga_module,
          saga_state: initial_saga_state,
          current_step: nil,
          current_step_index: -1,
          steps: steps,
          status: :running,
          retry_count: %{},
          started_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now(),
          executor_pid: executor_pid,
          step_started_at: nil,
          compensation_index: nil
        }

        # 初期状態を保存
        :ok = save_state(data)

        # 最初のステップを開始
        {:ok, :ready, data, [{:next_event, :internal, :start_next_step}]}

      {:restore, saga_data, saga_module, executor_pid} ->
        # 既存 Saga の復元
        data = %Data{
          saga_id: saga_data.saga_id,
          saga_module: saga_module,
          saga_state: saga_data.saga_state,
          current_step: saga_data.current_step,
          current_step_index: saga_data.current_step_index,
          steps: saga_module.steps(),
          status: String.to_atom(saga_data.status),
          failure_reason: saga_data.failure_reason,
          retry_count: saga_data.retry_count || %{},
          started_at: saga_data.started_at,
          updated_at: DateTime.utc_now(),
          executor_pid: executor_pid,
          step_started_at: saga_data.step_started_at,
          compensation_index: saga_data.compensation_index
        }

        # 状態に応じて再開
        case data.status do
          :running ->
            {:ok, :executing_step, data, [{:next_event, :internal, :check_step_status}]}

          :compensating ->
            {:ok, :compensating, data, [{:next_event, :internal, :continue_compensation}]}

          status when status in [:completed, :failed] ->
            {:ok, :terminated, data}
        end
    end
  end

  # State: ready (次のステップを開始する準備ができている)
  def ready(:internal, :start_next_step, data) do
    next_step_index = data.current_step_index + 1

    if next_step_index < length(data.steps) do
      step = Enum.at(data.steps, next_step_index)

      Logger.info("Starting step: saga_id=#{data.saga_id}, step=#{step.name}")

      # ステップを実行
      case execute_step(step, data) do
        {:ok, commands} ->
          # コマンドを発行
          Enum.each(commands, &dispatch_command/1)

          # 状態を更新
          new_data = %{
            data
            | current_step: step.name,
              current_step_index: next_step_index,
              step_started_at: DateTime.utc_now(),
              updated_at: DateTime.utc_now()
          }

          :ok = save_state(new_data)

          # タイムアウトを設定
          send(data.executor_pid, {:step_started, data.saga_id, step.name, step.timeout})

          {:next_state, :executing_step, new_data}

        {:error, reason} ->
          handle_step_error(step, reason, data)
      end
    else
      # 全ステップ完了
      complete_saga(data)
    end
  end

  def ready({:call, from}, :get_state, data) do
    {:keep_state_and_data, [{:reply, from, {:ok, format_state(data)}}]}
  end

  # State: executing_step (ステップ実行中)
  def executing_step(:internal, :check_step_status, data) do
    # 復元後のステップ状態を確認
    # 必要に応じてタイムアウトを再設定
    step = Enum.at(data.steps, data.current_step_index)

    if step && data.step_started_at do
      elapsed = DateTime.diff(DateTime.utc_now(), data.step_started_at, :millisecond)
      remaining = max(0, step.timeout - elapsed)

      if remaining > 0 do
        send(data.executor_pid, {:step_started, data.saga_id, step.name, remaining})
      else
        # 既にタイムアウトしている
        {:keep_state_and_data, [{:next_event, :internal, {:timeout, step.name}}]}
      end
    end

    :keep_state_and_data
  end

  def executing_step({:call, from}, {:handle_event, event}, data) do
    # イベントを Saga モジュールに渡す
    case data.saga_module.handle_event(event, data.saga_state) do
      {:ok, new_saga_state} ->
        new_data = %{data | saga_state: new_saga_state, updated_at: DateTime.utc_now()}
        :ok = save_state(new_data)

        # 現在のステップが完了したか確認
        if step_completed?(new_data) do
          send(data.executor_pid, {:step_completed, data.saga_id, data.current_step})

          {:next_state, :ready, new_data,
           [{:reply, from, :ok}, {:next_event, :internal, :start_next_step}]}
        else
          {:keep_state, new_data, [{:reply, from, :ok}]}
        end

      :ignore ->
        {:keep_state_and_data, [{:reply, from, :ok}]}

      {:error, reason} ->
        step = Enum.at(data.steps, data.current_step_index)
        {next_state, new_data} = handle_step_error(step, reason, data)
        {:next_state, next_state, new_data, [{:reply, from, :ok}]}
    end
  end

  def executing_step({:call, from}, {:handle_timeout, step_name}, data) do
    if data.current_step == step_name do
      Logger.warning("Step timeout: saga_id=#{data.saga_id}, step=#{step_name}")

      step = Enum.at(data.steps, data.current_step_index)

      # タイムアウト処理
      {next_state, new_data} =
        if step.compensate_on_timeout do
          start_compensation(data, :timeout)
        else
          # リトライまたは失敗
          handle_step_error(step, :timeout, data)
        end

      {:next_state, next_state, new_data, [{:reply, from, :ok}]}
    else
      # 古いタイムアウト（無視）
      {:keep_state_and_data, [{:reply, from, :ok}]}
    end
  end

  def executing_step(:internal, {:timeout, step_name}, data) do
    # 内部タイムアウトイベント（復元時）
    executing_step({:call, self()}, {:handle_timeout, step_name}, data)
  end

  def executing_step({:call, from}, :get_state, data) do
    {:keep_state_and_data, [{:reply, from, {:ok, format_state(data)}}]}
  end

  # State: compensating (補償処理中)
  def compensating(:internal, :continue_compensation, data) do
    compensate_next_step(data)
  end

  def compensating(:internal, :compensate_step, data) do
    compensate_next_step(data)
  end

  def compensating({:call, from}, {:handle_event, event}, data) do
    # 補償中もイベントを処理
    case data.saga_module.handle_event(event, data.saga_state) do
      {:ok, new_saga_state} ->
        new_data = %{data | saga_state: new_saga_state, updated_at: DateTime.utc_now()}
        :ok = save_state(new_data)
        {:keep_state, new_data, [{:reply, from, :ok}]}

      _ ->
        {:keep_state_and_data, [{:reply, from, :ok}]}
    end
  end

  def compensating({:call, from}, :get_state, data) do
    {:keep_state_and_data, [{:reply, from, {:ok, format_state(data)}}]}
  end

  # State: terminated (終了状態)
  def terminated({:call, from}, :get_state, data) do
    {:keep_state_and_data, [{:reply, from, {:ok, format_state(data)}}]}
  end

  def terminated({:call, from}, _, _data) do
    {:keep_state_and_data, [{:reply, from, {:error, :saga_terminated}}]}
  end

  # Private Functions

  defp execute_step(step, data) do
    try do
      data.saga_module.execute_step(step.name, data.saga_state)
    rescue
      e ->
        Logger.error("Step execution failed: #{inspect(e)}")
        {:error, :execution_error}
    end
  end

  defp dispatch_command(command) do
    # コマンドをイベントバス経由で送信
    # 実際のコマンドディスパッチは各サービスの CommandBus が処理
    event = %{
      event_type: :saga_command,
      command: command,
      timestamp: DateTime.utc_now()
    }

    EventBus.publish("saga_commands", event)
    :ok
  end

  defp step_completed?(data) do
    # Saga モジュールに問い合わせて、現在のステップが完了したか確認
    # デフォルトでは、特定のフラグやイベントで判断
    case data.current_step do
      :reserve_inventory -> data.saga_state[:inventory_reserved] == true
      :process_payment -> data.saga_state[:payment_processed] == true
      :arrange_shipping -> data.saga_state[:shipping_arranged] == true
      :confirm_order -> data.saga_state[:order_confirmed] == true
      _ -> false
    end
  end

  defp handle_step_error(step, reason, data) do
    Logger.error(
      "Step failed: saga_id=#{data.saga_id}, step=#{step.name}, reason=#{inspect(reason)}"
    )

    # リトライ可能か確認
    retry_count = Map.get(data.retry_count, step.name, 0)

    if can_retry?(step, reason, retry_count, data) do
      # リトライ
      new_retry_count = Map.put(data.retry_count, step.name, retry_count + 1)
      new_data = %{data | retry_count: new_retry_count, updated_at: DateTime.utc_now()}
      :ok = save_state(new_data)

      # バックオフ後にリトライ
      delay = calculate_backoff(step.retry_policy, retry_count)
      Process.send_after(self(), {:retry_step, step.name}, delay)

      {:executing_step, new_data}
    else
      # 補償処理を開始
      start_compensation(data, reason)
    end
  end

  defp can_retry?(step, reason, retry_count, data) do
    step.retry_policy != nil &&
      retry_count < step.retry_policy.max_attempts &&
      data.saga_module.can_retry_step?(step.name, reason, data.saga_state)
  end

  defp calculate_backoff(retry_policy, retry_count) do
    base_delay = retry_policy.base_delay
    max_delay = retry_policy.max_delay

    delay =
      case retry_policy.backoff_type do
        :constant -> base_delay
        :linear -> base_delay * (retry_count + 1)
        :exponential -> base_delay * :math.pow(2, retry_count)
        _ -> base_delay
      end

    min(round(delay), max_delay)
  end

  defp start_compensation(data, failure_reason) do
    Logger.info(
      "Starting compensation: saga_id=#{data.saga_id}, reason=#{inspect(failure_reason)}"
    )

    new_data = %{
      data
      | status: :compensating,
        failure_reason: failure_reason,
        compensation_index: data.current_step_index,
        updated_at: DateTime.utc_now()
    }

    :ok = save_state(new_data)

    {:compensating, new_data, [{:next_event, :internal, :compensate_step}]}
  end

  defp compensate_next_step(data) do
    if data.compensation_index >= 0 do
      step = Enum.at(data.steps, data.compensation_index)

      Logger.info("Compensating step: saga_id=#{data.saga_id}, step=#{step.name}")

      # 補償ステップを実行
      case compensate_step(step, data) do
        {:ok, commands} ->
          # 補償コマンドを発行
          Enum.each(commands, &dispatch_command/1)

          # 次の補償ステップへ
          new_data = %{
            data
            | compensation_index: data.compensation_index - 1,
              updated_at: DateTime.utc_now()
          }

          :ok = save_state(new_data)

          # 少し待ってから次のステップ
          Process.send_after(self(), :compensate_next, 100)

          :keep_state

        {:error, reason} ->
          Logger.error(
            "Compensation failed: saga_id=#{data.saga_id}, step=#{step.name}, reason=#{inspect(reason)}"
          )

          # 補償も失敗した場合は続行
          new_data = %{
            data
            | compensation_index: data.compensation_index - 1,
              updated_at: DateTime.utc_now()
          }

          :ok = save_state(new_data)

          Process.send_after(self(), :compensate_next, 100)

          {:keep_state, new_data}
      end
    else
      # 全補償完了
      fail_saga(data)
    end
  end

  defp compensate_step(step, data) do
    try do
      data.saga_module.compensate_step(step.name, data.saga_state)
    rescue
      e ->
        Logger.error("Compensation execution failed: #{inspect(e)}")
        {:error, :compensation_error}
    end
  end

  defp complete_saga(data) do
    Logger.info("Saga completed: saga_id=#{data.saga_id}")

    new_data = %{data | status: :completed, updated_at: DateTime.utc_now()}

    :ok = save_state(new_data)

    # 完了イベントを発行
    publish_saga_event(:saga_completed, new_data)

    # SagaExecutor に通知
    send(data.executor_pid, {:saga_completed, data.saga_id})

    {:next_state, :terminated, new_data}
  end

  defp fail_saga(data) do
    Logger.info("Saga failed: saga_id=#{data.saga_id}")

    new_data = %{data | status: :failed, updated_at: DateTime.utc_now()}

    :ok = save_state(new_data)

    # 失敗イベントを発行
    publish_saga_event(:saga_failed, new_data)

    # SagaExecutor に通知
    send(data.executor_pid, {:saga_failed, data.saga_id, data.failure_reason})

    {:next_state, :terminated, new_data}
  end

  defp save_state(data) do
    saga_data = %{
      saga_id: data.saga_id,
      saga_name: data.saga_module.saga_name(),
      saga_state: data.saga_state,
      current_step: data.current_step,
      current_step_index: data.current_step_index,
      status: Atom.to_string(data.status),
      failure_reason: data.failure_reason,
      retry_count: data.retry_count,
      started_at: data.started_at,
      updated_at: data.updated_at,
      step_started_at: data.step_started_at,
      compensation_index: data.compensation_index
    }

    SagaRepository.save_saga(saga_data)
  end

  defp format_state(data) do
    %{
      saga_id: data.saga_id,
      saga_name: data.saga_module.saga_name(),
      current_step: data.current_step,
      status: data.status,
      saga_state: data.saga_state,
      retry_count: data.retry_count,
      started_at: data.started_at,
      updated_at: data.updated_at
    }
  end

  defp publish_saga_event(event_type, data) do
    event = %{
      event_type: event_type,
      saga_id: data.saga_id,
      saga_name: data.saga_module.saga_name(),
      status: data.status,
      timestamp: DateTime.utc_now()
    }

    EventBus.publish("saga_events", event)
  end

  # Handle internal messages
  def handle_info({:retry_step, step_name}, :executing_step, data) do
    if data.current_step == step_name do
      # ステップを再実行
      step = Enum.at(data.steps, data.current_step_index)

      case execute_step(step, data) do
        {:ok, commands} ->
          Enum.each(commands, &dispatch_command/1)

          new_data = %{data | step_started_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}

          :ok = save_state(new_data)

          # タイムアウトを再設定
          send(data.executor_pid, {:step_started, data.saga_id, step.name, step.timeout})

          {:keep_state, new_data}

        {:error, reason} ->
          {next_state, new_data} = handle_step_error(step, reason, data)
          {:next_state, next_state, new_data}
      end
    else
      :keep_state_and_data
    end
  end

  def handle_info(:compensate_next, :compensating, data) do
    compensate_next_step(data)
  end

  def handle_info(msg, state, _data) do
    Logger.debug("Unhandled message in state #{state}: #{inspect(msg)}")
    :keep_state_and_data
  end
end

defmodule Shared.Infrastructure.Saga.SagaState do
  @moduledoc """
  Sagaの状態を管理する構造体

  Sagaの実行状態、現在のステップ、タイムアウト情報、
  実行履歴などを保持する。
  """

  @enforce_keys [:id, :saga_type, :status, :current_step, :data]
  defstruct [
    :id,
    :saga_type,
    :status,
    :current_step,
    :data,
    :completed_steps,
    :failed_step,
    :failure_reason,
    :step_timeouts,
    :step_started_at,
    :retry_counts,
    :compensation_state,
    :created_at,
    :updated_at,
    :completed_at,
    :failed_at,
    :metadata,
    :lock_ref,
    :resource_lock_ref
  ]

  @type status :: :pending | :running | :compensating | :completed | :failed | :timeout
  @type step_name :: atom()

  @type t :: %__MODULE__{
          id: String.t(),
          saga_type: module(),
          status: status(),
          current_step: step_name() | nil,
          data: map(),
          completed_steps: [step_name()],
          failed_step: step_name() | nil,
          failure_reason: any() | nil,
          step_timeouts: %{step_name() => reference()},
          step_started_at: %{step_name() => DateTime.t()},
          retry_counts: %{step_name() => non_neg_integer()},
          compensation_state: :not_started | :in_progress | :completed | :failed,
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          completed_at: DateTime.t() | nil,
          failed_at: DateTime.t() | nil,
          metadata: map(),
          lock_ref: reference() | nil,
          resource_lock_ref: reference() | nil
        }

  @doc """
  新しいSaga状態を作成
  """
  def new(id, saga_type, initial_data, metadata \\ %{}) do
    now = DateTime.utc_now()

    %__MODULE__{
      id: id,
      saga_type: saga_type,
      status: :pending,
      current_step: nil,
      data: initial_data,
      completed_steps: [],
      failed_step: nil,
      failure_reason: nil,
      step_timeouts: %{},
      step_started_at: %{},
      retry_counts: %{},
      compensation_state: :not_started,
      created_at: now,
      updated_at: now,
      completed_at: nil,
      failed_at: nil,
      metadata: metadata
    }
  end

  @doc """
  ステップを開始
  """
  def start_step(state, step_name) do
    %{
      state
      | status: :running,
        current_step: step_name,
        step_started_at: Map.put(state.step_started_at, step_name, DateTime.utc_now()),
        updated_at: DateTime.utc_now()
    }
  end

  @doc """
  ステップを完了
  """
  def complete_step(state, step_name) do
    %{
      state
      | completed_steps: state.completed_steps ++ [step_name],
        current_step: nil,
        step_timeouts: Map.delete(state.step_timeouts, step_name),
        updated_at: DateTime.utc_now()
    }
  end

  @doc """
  ステップが失敗
  """
  def fail_step(state, step_name, reason) do
    %{
      state
      | status: :failed,
        failed_step: step_name,
        failure_reason: reason,
        step_timeouts: Map.delete(state.step_timeouts, step_name),
        failed_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
    }
  end

  @doc """
  タイムアウトを記録
  """
  def record_timeout(state, step_name, timer_ref) do
    %{
      state
      | step_timeouts: Map.put(state.step_timeouts, step_name, timer_ref),
        updated_at: DateTime.utc_now()
    }
  end

  @doc """
  タイムアウトをクリア
  """
  def clear_timeout(state, step_name) do
    case Map.get(state.step_timeouts, step_name) do
      nil ->
        state

      timer_ref ->
        Process.cancel_timer(timer_ref)

        %{
          state
          | step_timeouts: Map.delete(state.step_timeouts, step_name),
            updated_at: DateTime.utc_now()
        }
    end
  end

  @doc """
  リトライ回数を増加
  """
  def increment_retry(state, step_name) do
    current_count = Map.get(state.retry_counts, step_name, 0)

    %{
      state
      | retry_counts: Map.put(state.retry_counts, step_name, current_count + 1),
        updated_at: DateTime.utc_now()
    }
  end

  @doc """
  補償処理を開始
  """
  def start_compensation(state) do
    %{
      state
      | status: :compensating,
        compensation_state: :in_progress,
        updated_at: DateTime.utc_now()
    }
  end

  @doc """
  補償処理を完了
  """
  def complete_compensation(state) do
    %{state | compensation_state: :completed, updated_at: DateTime.utc_now()}
  end

  @doc """
  補償処理が失敗
  """
  def fail_compensation(state, reason) do
    %{
      state
      | compensation_state: :failed,
        failure_reason: {:compensation_failed, reason},
        updated_at: DateTime.utc_now()
    }
  end

  @doc """
  Sagaを完了
  """
  def complete(state) do
    %{
      state
      | status: :completed,
        current_step: nil,
        completed_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
    }
  end

  @doc """
  タイムアウト状態に設定
  """
  def timeout(state, step_name) do
    %{
      state
      | status: :timeout,
        failed_step: step_name,
        failure_reason: {:timeout, step_name},
        failed_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
    }
  end

  @doc """
  データを更新
  """
  def update_data(state, updates) when is_map(updates) do
    %{state | data: Map.merge(state.data, updates), updated_at: DateTime.utc_now()}
  end

  @doc """
  ステップの実行時間を取得
  """
  def get_step_duration(state, step_name) do
    case Map.get(state.step_started_at, step_name) do
      nil ->
        nil

      started_at ->
        end_time =
          if step_name in state.completed_steps do
            # 完了したステップの場合、次のステップの開始時刻または現在時刻
            next_step_start =
              state.step_started_at
              |> Enum.filter(fn {_, time} -> DateTime.compare(time, started_at) == :gt end)
              |> Enum.min_by(fn {_, time} -> time end, fn -> {nil, DateTime.utc_now()} end)
              |> elem(1)

            next_step_start
          else
            DateTime.utc_now()
          end

        DateTime.diff(end_time, started_at, :millisecond)
    end
  end
end

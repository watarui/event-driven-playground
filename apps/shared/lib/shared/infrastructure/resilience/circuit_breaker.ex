defmodule Shared.Infrastructure.Resilience.CircuitBreaker do
  @moduledoc """
  サーキットブレーカーパターンの実装

  障害の連鎖を防ぎ、システムの復旧時間を短縮する。

  ## 状態
  - `:closed` - 正常状態。リクエストは通常通り処理される
  - `:open` - 遮断状態。すべてのリクエストが即座に失敗
  - `:half_open` - 半開状態。限定的なリクエストを通してテスト

  ## 設定可能なパラメータ
  - `:failure_threshold` - 失敗回数の閾値（デフォルト: 5）
  - `:success_threshold` - 復旧に必要な成功回数（デフォルト: 3）
  - `:timeout` - Open状態のタイムアウト（ミリ秒、デフォルト: 60000）
  - `:reset_timeout` - 統計情報のリセット間隔（ミリ秒、デフォルト: 120000）
  """

  use GenServer

  require Logger

  defstruct [:name, :state, :failure_count, :success_count, :last_failure_time, :config, :stats]

  @type state :: :closed | :open | :half_open
  @type config :: %{
          failure_threshold: non_neg_integer(),
          success_threshold: non_neg_integer(),
          timeout: non_neg_integer(),
          reset_timeout: non_neg_integer()
        }

  @default_config %{
    failure_threshold: 5,
    success_threshold: 3,
    timeout: 60_000,
    reset_timeout: 120_000
  }

  # Client API

  @doc """
  child_spec を定義
  """
  def child_spec(opts) do
    name = Keyword.get(opts, :name, __MODULE__)

    %{
      id: :"#{__MODULE__}_#{name}",
      start: {__MODULE__, :start_link, [opts]},
      restart: :permanent,
      type: :worker
    }
  end

  @doc """
  新しいサーキットブレーカーを開始する

  ## Options
  - `:name` - サーキットブレーカーの名前（必須）
  - `:failure_threshold` - 失敗回数の閾値
  - `:success_threshold` - 復旧に必要な成功回数
  - `:timeout` - Open状態のタイムアウト（ミリ秒）
  - `:reset_timeout` - 統計情報のリセット間隔（ミリ秒）
  """
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(name))
  end

  @doc """
  サーキットブレーカーを通じて関数を実行する

  ## Examples
      iex> CircuitBreaker.call(:my_service, fn -> {:ok, "result"} end)
      {:ok, "result"}

      iex> CircuitBreaker.call(:my_service, fn -> {:error, "failed"} end)
      {:error, "failed"}
  """
  @spec call(atom(), (-> any())) :: {:ok, any()} | {:error, :circuit_open} | {:error, any()}
  def call(name, fun) do
    GenServer.call(via_tuple(name), {:call, fun})
  catch
    :exit, {:noproc, _} ->
      Logger.error("Circuit breaker #{name} not started")
      {:error, :circuit_breaker_not_found}
  end

  @doc """
  サーキットブレーカーの現在の状態を取得する
  """
  @spec get_state(atom()) :: {:ok, state()} | {:error, :not_found}
  def get_state(name) do
    GenServer.call(via_tuple(name), :get_state)
  catch
    :exit, {:noproc, _} ->
      {:error, :not_found}
  end

  @doc """
  サーキットブレーカーの統計情報を取得する
  """
  @spec get_stats(atom()) :: {:ok, map()} | {:error, :not_found}
  def get_stats(name) do
    GenServer.call(via_tuple(name), :get_stats)
  catch
    :exit, {:noproc, _} ->
      {:error, :not_found}
  end

  @doc """
  サーキットブレーカーを手動でリセットする
  """
  @spec reset(atom()) :: :ok | {:error, :not_found}
  def reset(name) do
    GenServer.cast(via_tuple(name), :reset)
  catch
    :exit, {:noproc, _} ->
      {:error, :not_found}
  end

  # Server callbacks

  @impl true
  def init(opts) do
    name = Keyword.fetch!(opts, :name)

    config =
      @default_config
      |> Map.merge(
        Keyword.take(opts, [:failure_threshold, :success_threshold, :timeout, :reset_timeout])
        |> Map.new()
      )

    state = %__MODULE__{
      name: name,
      state: :closed,
      failure_count: 0,
      success_count: 0,
      last_failure_time: nil,
      config: config,
      stats: %{
        total_calls: 0,
        total_failures: 0,
        total_successes: 0,
        circuit_opens: 0,
        last_opened_at: nil
      }
    }

    # 統計情報の定期リセット
    schedule_stats_reset(config.reset_timeout)

    {:ok, state}
  end

  @impl true
  def handle_call({:call, fun}, _from, state) do
    case state.state do
      :open ->
        # Open状態のタイムアウトをチェック
        if should_attempt_reset?(state) do
          # Half-Open状態に移行
          new_state = transition_to_half_open(state)
          execute_and_track(fun, new_state)
        else
          # まだOpen状態
          {:reply, {:error, :circuit_open}, update_stats(state, :rejected)}
        end

      :closed ->
        execute_and_track(fun, state)

      :half_open ->
        execute_and_track(fun, state)
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state.state}, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats =
      Map.merge(state.stats, %{
        current_state: state.state,
        failure_count: state.failure_count,
        success_count: state.success_count
      })

    {:reply, {:ok, stats}, state}
  end

  @impl true
  def handle_cast(:reset, state) do
    Logger.info("Circuit breaker #{state.name} manually reset")

    new_state = %{
      state
      | state: :closed,
        failure_count: 0,
        success_count: 0,
        last_failure_time: nil
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:reset_stats, state) do
    # 統計情報の部分リセット（現在の状態は保持）
    new_stats = %{
      state.stats
      | total_calls: div(state.stats.total_calls, 2),
        total_failures: div(state.stats.total_failures, 2),
        total_successes: div(state.stats.total_successes, 2)
    }

    schedule_stats_reset(state.config.reset_timeout)
    {:noreply, %{state | stats: new_stats}}
  end

  # Private functions

  defp via_tuple(name) do
    {:via, Registry, {Shared.CircuitBreakerRegistry, name}}
  end

  defp execute_and_track(fun, state) do
    start_time = System.monotonic_time(:microsecond)

    try do
      case fun.() do
        {:ok, result} ->
          duration = System.monotonic_time(:microsecond) - start_time
          emit_telemetry(:success, state.name, duration)
          new_state = handle_success(state)
          {:reply, {:ok, result}, new_state}

        {:error, _reason} = error ->
          duration = System.monotonic_time(:microsecond) - start_time
          emit_telemetry(:failure, state.name, duration)
          new_state = handle_failure(state)
          {:reply, error, new_state}

        other ->
          # 予期しない戻り値は成功として扱う
          duration = System.monotonic_time(:microsecond) - start_time
          emit_telemetry(:success, state.name, duration)
          new_state = handle_success(state)
          {:reply, {:ok, other}, new_state}
      end
    rescue
      e ->
        duration = System.monotonic_time(:microsecond) - start_time
        emit_telemetry(:failure, state.name, duration)
        new_state = handle_failure(state)
        {:reply, {:error, Exception.message(e)}, new_state}
    end
  end

  defp handle_success(state) do
    new_state = update_stats(state, :success)

    case state.state do
      :half_open ->
        success_count = state.success_count + 1

        if success_count >= state.config.success_threshold do
          # Closed状態に復帰
          Logger.info("Circuit breaker #{state.name} closed after #{success_count} successes")
          %{new_state | state: :closed, failure_count: 0, success_count: 0}
        else
          %{new_state | success_count: success_count}
        end

      :closed ->
        # 失敗カウントをリセット
        %{new_state | failure_count: 0}

      :open ->
        # Open状態では到達しないはず
        new_state
    end
  end

  defp handle_failure(state) do
    new_state = update_stats(state, :failure)
    failure_count = state.failure_count + 1

    case state.state do
      :closed ->
        if failure_count >= state.config.failure_threshold do
          # Open状態に移行
          Logger.warning("Circuit breaker #{state.name} opened after #{failure_count} failures")

          %{
            new_state
            | state: :open,
              failure_count: failure_count,
              last_failure_time: System.monotonic_time(:millisecond),
              stats:
                Map.merge(new_state.stats, %{
                  circuit_opens: new_state.stats.circuit_opens + 1,
                  last_opened_at: DateTime.utc_now()
                })
          }
        else
          %{new_state | failure_count: failure_count}
        end

      :half_open ->
        # 即座にOpen状態に戻る
        Logger.warning("Circuit breaker #{state.name} reopened after failure in half-open state")

        %{
          new_state
          | state: :open,
            failure_count: 0,
            success_count: 0,
            last_failure_time: System.monotonic_time(:millisecond)
        }

      :open ->
        # Open状態では到達しないはず
        new_state
    end
  end

  defp should_attempt_reset?(state) do
    state.last_failure_time != nil and
      System.monotonic_time(:millisecond) - state.last_failure_time >= state.config.timeout
  end

  defp transition_to_half_open(state) do
    Logger.info("Circuit breaker #{state.name} transitioning to half-open")
    %{state | state: :half_open, success_count: 0, failure_count: 0}
  end

  defp update_stats(state, :success) do
    %{
      state
      | stats: %{
          state.stats
          | total_calls: state.stats.total_calls + 1,
            total_successes: state.stats.total_successes + 1
        }
    }
  end

  defp update_stats(state, :failure) do
    %{
      state
      | stats: %{
          state.stats
          | total_calls: state.stats.total_calls + 1,
            total_failures: state.stats.total_failures + 1
        }
    }
  end

  defp update_stats(state, :rejected) do
    %{state | stats: %{state.stats | total_calls: state.stats.total_calls + 1}}
  end

  defp schedule_stats_reset(timeout) do
    Process.send_after(self(), :reset_stats, timeout)
  end

  defp emit_telemetry(event_type, name, duration) do
    :telemetry.execute(
      [:circuit_breaker, event_type],
      %{duration: duration},
      %{name: name}
    )
  end
end

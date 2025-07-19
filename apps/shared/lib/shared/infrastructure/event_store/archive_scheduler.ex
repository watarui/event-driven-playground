defmodule Shared.Infrastructure.EventStore.ArchiveScheduler do
  @moduledoc """
  イベントアーカイブのスケジューラー

  定期的に古いイベントをアーカイブする
  """

  use GenServer
  alias Shared.Infrastructure.EventStore.EventArchiver
  require Logger

  # デフォルト設定
  # 24時間ごと
  @default_schedule_interval :timer.hours(24)
  @default_archive_after_days 90
  # 午前2時に実行
  @default_run_at_hour 2

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Public API

  @doc """
  手動でアーカイブを実行する
  """
  def run_archive_now do
    GenServer.cast(__MODULE__, :run_archive)
  end

  @doc """
  次回のアーカイブ実行時刻を取得する
  """
  def get_next_run_time do
    GenServer.call(__MODULE__, :get_next_run_time)
  end

  @doc """
  アーカイブスケジューラーの状態を取得する
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    state = %{
      enabled: Keyword.get(opts, :enabled, true),
      schedule_interval: Keyword.get(opts, :schedule_interval, @default_schedule_interval),
      archive_after_days: Keyword.get(opts, :archive_after_days, @default_archive_after_days),
      run_at_hour: Keyword.get(opts, :run_at_hour, @default_run_at_hour),
      last_run: nil,
      next_run: nil,
      running: false
    }

    if state.enabled do
      schedule_next_run(state)
    end

    {:ok, state}
  end

  @impl true
  def handle_cast(:run_archive, %{running: true} = state) do
    Logger.info("Archive already running, skipping...")
    {:noreply, state}
  end

  @impl true
  def handle_cast(:run_archive, state) do
    Logger.info("Starting manual event archive...")
    state = run_archive(state)
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_next_run_time, _from, state) do
    {:reply, state.next_run, state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      enabled: state.enabled,
      running: state.running,
      last_run: state.last_run,
      next_run: state.next_run,
      archive_after_days: state.archive_after_days
    }

    {:reply, status, state}
  end

  @impl true
  def handle_info(:run_scheduled_archive, %{enabled: false} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(:run_scheduled_archive, state) do
    Logger.info("Starting scheduled event archive...")
    state = run_archive(state)

    # 次回の実行をスケジュール
    state = schedule_next_run(state)

    {:noreply, state}
  end

  # Private functions

  defp run_archive(state) do
    state = %{state | running: true}

    start_time = DateTime.utc_now()

    result = EventArchiver.archive_old_events(state.archive_after_days)

    end_time = DateTime.utc_now()
    duration_ms = DateTime.diff(end_time, start_time, :millisecond)

    case result do
      {:ok, count} ->
        Logger.info(
          "Archive completed successfully. Archived #{count} events in #{duration_ms}ms"
        )

      {:error, reason} ->
        Logger.error("Archive failed: #{inspect(reason)}")
    end

    %{
      state
      | running: false,
        last_run: %{
          started_at: start_time,
          completed_at: end_time,
          duration_ms: duration_ms,
          result: result
        }
    }
  end

  defp schedule_next_run(state) do
    next_run_time = calculate_next_run_time(state.run_at_hour)

    # 次回実行までのミリ秒を計算
    delay_ms = DateTime.diff(next_run_time, DateTime.utc_now(), :millisecond)

    # タイマーをセット
    Process.send_after(self(), :run_scheduled_archive, delay_ms)

    Logger.info("Next archive scheduled for #{next_run_time}")

    %{state | next_run: next_run_time}
  end

  defp calculate_next_run_time(run_at_hour) do
    now = DateTime.utc_now()
    today_run_time = %{now | hour: run_at_hour, minute: 0, second: 0, microsecond: {0, 0}}

    # 今日の実行時刻を過ぎている場合は明日
    if DateTime.compare(now, today_run_time) == :gt do
      DateTime.add(today_run_time, 24 * 60 * 60, :second)
    else
      today_run_time
    end
  end
end

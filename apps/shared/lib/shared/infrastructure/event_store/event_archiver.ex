defmodule Shared.Infrastructure.EventStore.EventArchiver do
  @moduledoc """
  イベントアーカイブ機能

  古いイベントを自動的にアーカイブテーブルに移動し、
  メインテーブルのパフォーマンスを維持する。
  """

  use GenServer

  import Ecto.Query

  alias Shared.Infrastructure.EventStore.Repo
  alias Shared.Infrastructure.EventStore.Schema.{Event, ArchivedEvent}

  require Logger

  @default_archive_interval :timer.hours(24)
  @default_retention_days 90
  @default_batch_size 1000

  # Client API

  @doc """
  EventArchiver を開始する
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  手動でアーカイブを実行する
  """
  @spec archive_now(keyword()) :: {:ok, integer()} | {:error, term()}
  def archive_now(opts \\ []) do
    GenServer.call(__MODULE__, {:archive_now, opts}, :infinity)
  end

  @doc """
  アーカイブされたイベントを取得する
  """
  @spec get_archived_events(keyword()) :: {:ok, [ArchivedEvent.t()]} | {:error, term()}
  def get_archived_events(opts \\ []) do
    aggregate_id = Keyword.get(opts, :aggregate_id)
    event_type = Keyword.get(opts, :event_type)
    start_date = Keyword.get(opts, :start_date)
    end_date = Keyword.get(opts, :end_date)
    limit = Keyword.get(opts, :limit, 100)

    query =
      ArchivedEvent
      |> maybe_filter_by_aggregate(aggregate_id)
      |> maybe_filter_by_event_type(event_type)
      |> maybe_filter_by_date_range(start_date, end_date)
      |> limit(^limit)
      |> order_by(desc: :event_timestamp)

    try do
      events = Repo.all(query)
      {:ok, events}
    rescue
      e ->
        Logger.error("Failed to fetch archived events: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc """
  アーカイブ統計を取得する
  """
  @spec get_archive_stats() :: {:ok, map()} | {:error, term()}
  def get_archive_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    # 設定の読み込み
    archive_interval = Keyword.get(opts, :archive_interval, @default_archive_interval)
    retention_days = Keyword.get(opts, :retention_days, @default_retention_days)
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)

    state = %{
      archive_interval: archive_interval,
      retention_days: retention_days,
      batch_size: batch_size,
      stats: %{
        last_archive_at: nil,
        total_archived: 0,
        total_deleted: 0
      }
    }

    # アーカイブテーブルの作成
    ensure_archive_table_exists()

    # 定期実行のスケジューリング
    schedule_next_archive(state)

    {:ok, state}
  end

  @impl true
  def handle_call({:archive_now, opts}, _from, state) do
    retention_days = Keyword.get(opts, :retention_days, state.retention_days)
    batch_size = Keyword.get(opts, :batch_size, state.batch_size)

    case do_archive_events(retention_days, batch_size) do
      {:ok, archived_count} ->
        new_stats = %{
          state.stats
          | last_archive_at: DateTime.utc_now(),
            total_archived: state.stats.total_archived + archived_count
        }

        {:reply, {:ok, archived_count}, %{state | stats: new_stats}}

      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats =
      Map.merge(state.stats, %{
        retention_days: state.retention_days,
        batch_size: state.batch_size,
        next_archive_in: get_next_archive_time(state)
      })

    {:reply, {:ok, stats}, state}
  end

  @impl true
  def handle_info(:archive_events, state) do
    Logger.info("Starting scheduled event archiving...")

    case do_archive_events(state.retention_days, state.batch_size) do
      {:ok, archived_count} ->
        Logger.info("Archived #{archived_count} events")

        new_stats = %{
          state.stats
          | last_archive_at: DateTime.utc_now(),
            total_archived: state.stats.total_archived + archived_count
        }

        # 次回のアーカイブをスケジュール
        schedule_next_archive(state)

        {:noreply, %{state | stats: new_stats}}

      {:error, reason} ->
        Logger.error("Failed to archive events: #{inspect(reason)}")

        # エラー時は短い間隔でリトライ
        Process.send_after(self(), :archive_events, :timer.minutes(5))

        {:noreply, state}
    end
  end

  # Private functions

  defp do_archive_events(retention_days, batch_size) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -retention_days * 24 * 60 * 60, :second)

    Repo.transaction(fn ->
      archived_count = archive_old_events(cutoff_date, batch_size)
      deleted_count = delete_expired_archives(retention_days * 2, batch_size)

      Logger.info("Archived #{archived_count} events, deleted #{deleted_count} expired archives")

      archived_count
    end)
  end

  defp archive_old_events(cutoff_date, batch_size) do
    # バッチごとにアーカイブ
    Stream.repeatedly(fn ->
      events_to_archive =
        Event
        |> where([e], e.event_timestamp < ^cutoff_date)
        |> limit(^batch_size)
        |> Repo.all()

      if Enum.empty?(events_to_archive) do
        :done
      else
        # アーカイブテーブルに挿入
        archived_events =
          Enum.map(events_to_archive, fn event ->
            %{
              id: event.id,
              aggregate_id: event.aggregate_id,
              aggregate_type: event.aggregate_type,
              event_type: event.event_type,
              event_version: event.event_version,
              event_data: event.event_data,
              metadata: event.metadata,
              event_timestamp: event.event_timestamp,
              archived_at: DateTime.utc_now(),
              inserted_at: DateTime.utc_now(),
              updated_at: DateTime.utc_now()
            }
          end)

        {inserted_count, _} = Repo.insert_all(ArchivedEvent, archived_events)

        # 元のイベントを削除
        event_ids = Enum.map(events_to_archive, & &1.id)

        {deleted_count, _} =
          Event
          |> where([e], e.id in ^event_ids)
          |> Repo.delete_all()

        if inserted_count == deleted_count do
          inserted_count
        else
          Logger.error(
            "Archive count mismatch: inserted #{inserted_count}, deleted #{deleted_count}"
          )

          raise "Archive count mismatch"
        end
      end
    end)
    |> Stream.take_while(&(&1 != :done))
    |> Enum.sum()
  end

  defp delete_expired_archives(max_retention_days, batch_size) do
    expiry_date = DateTime.add(DateTime.utc_now(), -max_retention_days * 24 * 60 * 60, :second)

    {deleted_count, _} =
      ArchivedEvent
      |> where([e], e.archived_at < ^expiry_date)
      |> limit(^batch_size)
      |> Repo.delete_all()

    deleted_count
  end

  defp ensure_archive_table_exists do
    # マイグレーションは別途作成するが、ここでは存在確認のみ
    :ok
  end

  defp schedule_next_archive(state) do
    Process.send_after(self(), :archive_events, state.archive_interval)
  end

  defp get_next_archive_time(state) do
    if state.stats.last_archive_at do
      next_time =
        DateTime.add(state.stats.last_archive_at, div(state.archive_interval, 1000), :second)

      seconds_until = DateTime.diff(next_time, DateTime.utc_now())

      if seconds_until > 0 do
        format_duration(seconds_until)
      else
        "soon"
      end
    else
      "pending"
    end
  end

  defp format_duration(seconds) when seconds < 60, do: "#{seconds}s"

  defp format_duration(seconds) when seconds < 3600 do
    minutes = div(seconds, 60)
    "#{minutes}m"
  end

  defp format_duration(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    "#{hours}h #{minutes}m"
  end

  # Query helpers

  defp maybe_filter_by_aggregate(query, nil), do: query

  defp maybe_filter_by_aggregate(query, aggregate_id) do
    where(query, [e], e.aggregate_id == ^aggregate_id)
  end

  defp maybe_filter_by_event_type(query, nil), do: query

  defp maybe_filter_by_event_type(query, event_type) do
    where(query, [e], e.event_type == ^event_type)
  end

  defp maybe_filter_by_date_range(query, nil, nil), do: query

  defp maybe_filter_by_date_range(query, start_date, nil) do
    where(query, [e], e.event_timestamp >= ^start_date)
  end

  defp maybe_filter_by_date_range(query, nil, end_date) do
    where(query, [e], e.event_timestamp <= ^end_date)
  end

  defp maybe_filter_by_date_range(query, start_date, end_date) do
    where(query, [e], e.event_timestamp >= ^start_date and e.event_timestamp <= ^end_date)
  end
end

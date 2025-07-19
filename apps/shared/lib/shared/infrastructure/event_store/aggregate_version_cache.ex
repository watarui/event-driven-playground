defmodule Shared.Infrastructure.EventStore.AggregateVersionCache do
  @moduledoc """
  アグリゲートバージョンのキャッシュ

  頻繁なバージョンチェックのパフォーマンスを向上させるために、
  最新バージョンをメモリにキャッシュします
  """

  use GenServer
  require Logger

  @table_name :aggregate_version_cache
  @cleanup_interval :timer.minutes(5)
  @max_entries 10_000

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  アグリゲートの現在のバージョンを取得する
  """
  def get_version(aggregate_id) do
    case :ets.lookup(@table_name, aggregate_id) do
      [{^aggregate_id, version, expiry}] ->
        if expiry == :infinity or DateTime.compare(expiry, DateTime.utc_now()) == :gt do
          {:ok, version}
        else
          # 期限切れのエントリを削除
          :ets.delete(@table_name, aggregate_id)
          {:error, :not_cached}
        end

      [] ->
        {:error, :not_cached}
    end
  end

  @doc """
  アグリゲートのバージョンを設定する
  """
  def set_version(aggregate_id, version) do
    GenServer.cast(__MODULE__, {:set_version, aggregate_id, version})
  end

  @doc """
  アグリゲートのバージョンをインクリメントする
  """
  def increment_version(aggregate_id, by \\ 1) do
    GenServer.call(__MODULE__, {:increment_version, aggregate_id, by})
  end

  @doc """
  キャッシュをクリアする
  """
  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    # ETS テーブルを作成
    :ets.new(@table_name, [:set, :public, :named_table, read_concurrency: true])

    # 定期的なクリーンアップを開始
    schedule_cleanup()

    {:ok, %{}}
  end

  @impl true
  def handle_cast({:set_version, aggregate_id, version}, state) do
    # 5分後
    expiry = DateTime.add(DateTime.utc_now(), 300, :second)
    :ets.insert(@table_name, {aggregate_id, version, expiry})

    # キャッシュサイズをチェック
    if :ets.info(@table_name, :size) > @max_entries do
      cleanup_old_entries()
    end

    {:noreply, state}
  end

  @impl true
  def handle_call({:increment_version, aggregate_id, by}, _from, state) do
    case get_version(aggregate_id) do
      {:ok, current_version} ->
        new_version = current_version + by
        expiry = DateTime.add(DateTime.utc_now(), 300, :second)
        :ets.insert(@table_name, {aggregate_id, new_version, expiry})
        {:reply, {:ok, new_version}, state}

      {:error, :not_cached} ->
        {:reply, {:error, :not_cached}, state}
    end
  end

  @impl true
  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(@table_name)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired_entries()
    schedule_cleanup()
    {:noreply, state}
  end

  # Private functions

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp cleanup_expired_entries do
    now = DateTime.utc_now()

    deleted =
      :ets.foldl(
        fn {aggregate_id, _version, expiry}, acc ->
          if expiry != :infinity and DateTime.compare(expiry, now) == :lt do
            :ets.delete(@table_name, aggregate_id)
            acc + 1
          else
            acc
          end
        end,
        0,
        @table_name
      )

    if deleted > 0 do
      Logger.debug("Version cache cleanup: removed #{deleted} expired entries")
    end
  end

  defp cleanup_old_entries do
    # 最も古いエントリを削除して容量を確保
    entries = :ets.tab2list(@table_name)

    sorted_entries =
      entries
      |> Enum.sort_by(fn {_id, _version, expiry} ->
        if expiry == :infinity do
          ~U[2999-12-31 23:59:59Z]
        else
          expiry
        end
      end)

    # 削除する数を計算
    # 90%まで削減
    to_delete = length(entries) - div(@max_entries * 9, 10)

    sorted_entries
    |> Enum.take(to_delete)
    |> Enum.each(fn {aggregate_id, _, _} ->
      :ets.delete(@table_name, aggregate_id)
    end)

    Logger.debug("Version cache cleanup: removed #{to_delete} old entries")
  end
end

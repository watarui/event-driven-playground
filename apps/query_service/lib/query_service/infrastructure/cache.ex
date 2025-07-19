defmodule QueryService.Infrastructure.Cache do
  @moduledoc """
  ETS ベースのキャッシュ実装

  クエリ結果を一時的にキャッシュし、パフォーマンスを向上させます
  """

  use GenServer
  require Logger

  # ETS テーブル名
  @table_name :query_cache
  # デフォルト TTL (5分)
  @default_ttl :timer.minutes(5)
  # クリーンアップ間隔 (1分)
  @cleanup_interval :timer.minutes(1)

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  キャッシュに値を設定する

  ## パラメータ
    - key: キャッシュキー
    - value: キャッシュする値
    - ttl: TTL (ミリ秒)。省略時はデフォルト値を使用

  ## 例
      Cache.put("product:123", product, :timer.minutes(10))
  """
  @spec put(any(), any(), non_neg_integer() | :infinity) :: :ok
  def put(key, value, ttl \\ @default_ttl) do
    GenServer.cast(__MODULE__, {:put, key, value, ttl})
  end

  @doc """
  キャッシュから値を取得する

  ## 戻り値
    - {:ok, value} - キャッシュヒット
    - {:error, :not_found} - キャッシュミス
  """
  @spec get(any()) :: {:ok, any()} | {:error, :not_found}
  def get(key) do
    case :ets.lookup(@table_name, key) do
      [{^key, value, expiry}] ->
        if expiry == :infinity or DateTime.compare(expiry, DateTime.utc_now()) == :gt do
          {:ok, value}
        else
          # 期限切れのエントリを削除
          :ets.delete(@table_name, key)
          {:error, :not_found}
        end

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  キャッシュから値を削除する
  """
  @spec delete(any()) :: :ok
  def delete(key) do
    GenServer.cast(__MODULE__, {:delete, key})
  end

  @doc """
  パターンに一致するキーをすべて削除する

  ## 例
      # "product:" で始まるすべてのキーを削除
      Cache.delete_pattern("product:*")
  """
  @spec delete_pattern(String.t()) :: :ok
  def delete_pattern(pattern) do
    GenServer.cast(__MODULE__, {:delete_pattern, pattern})
  end

  @doc """
  キャッシュをクリアする
  """
  @spec clear() :: :ok
  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  @doc """
  キャッシュ統計を取得する
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc """
  キャッシュフェッチ関数

  キャッシュにヒットしない場合は、関数を実行して結果をキャッシュする

  ## 例
      Cache.fetch("expensive_query", fn ->
        # 時間のかかる処理
        {:ok, result}
      end)
  """
  @spec fetch(any(), function(), non_neg_integer()) :: {:ok, any()} | {:error, any()}
  def fetch(key, fun, ttl \\ @default_ttl) do
    case get(key) do
      {:ok, value} ->
        {:ok, value}

      {:error, :not_found} ->
        case fun.() do
          {:ok, value} ->
            put(key, value, ttl)
            {:ok, value}

          {:error, _} = error ->
            error
        end
    end
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    # ETS テーブルを作成
    table = :ets.new(@table_name, [:set, :public, :named_table, read_concurrency: true])

    # 定期的なクリーンアップを開始
    schedule_cleanup()

    state = %{
      table: table,
      hits: 0,
      misses: 0,
      puts: 0,
      deletes: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:put, key, value, ttl}, state) do
    expiry =
      if ttl == :infinity do
        :infinity
      else
        DateTime.add(DateTime.utc_now(), ttl, :millisecond)
      end

    :ets.insert(@table_name, {key, value, expiry})
    {:noreply, %{state | puts: state.puts + 1}}
  end

  @impl true
  def handle_cast({:delete, key}, state) do
    :ets.delete(@table_name, key)
    {:noreply, %{state | deletes: state.deletes + 1}}
  end

  @impl true
  def handle_cast({:delete_pattern, pattern}, state) do
    # パターンを正規表現に変換
    regex = pattern_to_regex(pattern)

    # マッチするキーを削除
    :ets.foldl(
      fn {key, _, _}, acc ->
        key_string = to_string(key)

        if Regex.match?(regex, key_string) do
          :ets.delete(@table_name, key)
          acc + 1
        else
          acc
        end
      end,
      0,
      @table_name
    )

    {:noreply, state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(@table_name)
    {:reply, :ok, %{state | hits: 0, misses: 0, puts: 0, deletes: 0}}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    size = :ets.info(@table_name, :size)

    stats = %{
      size: size,
      hits: state.hits,
      misses: state.misses,
      puts: state.puts,
      deletes: state.deletes,
      hit_rate:
        if state.hits + state.misses > 0 do
          state.hits / (state.hits + state.misses) * 100
        else
          0.0
        end
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    # 期限切れのエントリを削除
    now = DateTime.utc_now()

    deleted =
      :ets.foldl(
        fn {key, _value, expiry}, acc ->
          if expiry != :infinity and DateTime.compare(expiry, now) == :lt do
            :ets.delete(@table_name, key)
            acc + 1
          else
            acc
          end
        end,
        0,
        @table_name
      )

    if deleted > 0 do
      Logger.debug("Cache cleanup: removed #{deleted} expired entries")
    end

    # 次のクリーンアップをスケジュール
    schedule_cleanup()

    {:noreply, state}
  end

  # Private functions

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp pattern_to_regex(pattern) do
    pattern
    |> String.replace("*", ".*")
    |> String.replace("?", ".")
    |> Regex.compile!()
  end
end

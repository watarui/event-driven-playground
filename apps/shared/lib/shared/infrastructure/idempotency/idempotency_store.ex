defmodule Shared.Infrastructure.Idempotency.IdempotencyStore do
  @moduledoc """
  べき等性を保証するための結果キャッシュストア

  処理結果をキャッシュし、同じリクエストが再度来た場合は
  キャッシュした結果を返すことで、べき等性を保証する。
  """

  use GenServer
  import Ecto.Query

  alias Shared.Infrastructure.EventStore.Repo
  alias Shared.Infrastructure.Idempotency.IdempotencyRecord

  require Logger

  @cleanup_interval_minutes 60
  @table_name :idempotency_cache

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  べき等性キーで操作を実行する

  キャッシュがある場合はキャッシュした結果を返し、
  ない場合は操作を実行して結果をキャッシュする。

  ## Parameters
  - `idempotency_key` - べき等性キー
  - `operation` - 実行する操作（0引数の関数）
  - `opts` - オプション
    - `:ttl` - キャッシュの有効期限（秒）
    
  ## Examples
      iex> IdempotencyStore.execute("cmd:order-123:create", fn ->
      ...>   {:ok, create_order()}
      ...> end)
      {:ok, %Order{}}  # 初回は実行
      
      iex> IdempotencyStore.execute("cmd:order-123:create", fn ->
      ...>   {:ok, create_order()}
      ...> end)
      {:ok, %Order{}}  # 2回目はキャッシュから返す
  """
  @spec execute(String.t(), function(), keyword()) :: {:ok, any()} | {:error, any()}
  def execute(idempotency_key, operation, opts \\ []) do
    GenServer.call(__MODULE__, {:execute, idempotency_key, operation, opts}, 30_000)
  end

  @doc """
  べき等性キーの結果を取得する
  """
  @spec get(String.t()) :: {:ok, any()} | {:error, :not_found}
  def get(idempotency_key) do
    GenServer.call(__MODULE__, {:get, idempotency_key})
  end

  @doc """
  べき等性キーの結果を保存する
  """
  @spec put(String.t(), any(), keyword()) :: :ok
  def put(idempotency_key, result, opts \\ []) do
    GenServer.cast(__MODULE__, {:put, idempotency_key, result, opts})
  end

  @doc """
  べき等性キーを削除する
  """
  @spec delete(String.t()) :: :ok
  def delete(idempotency_key) do
    GenServer.cast(__MODULE__, {:delete, idempotency_key})
  end

  @doc """
  統計情報を取得する
  """
  @spec get_stats() :: {:ok, map()}
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # ETSテーブルを作成（高速アクセス用）
    :ets.new(@table_name, [:set, :named_table, :public, read_concurrency: true])

    # 定期的なクリーンアップをスケジュール
    schedule_cleanup()

    # DBから既存のレコードを復元
    restore_from_db()

    state = %{
      stats: %{
        hits: 0,
        misses: 0,
        executions: 0,
        errors: 0
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:execute, idempotency_key, operation, opts}, _from, state) do
    # デフォルト1時間
    ttl = Keyword.get(opts, :ttl, 3600)

    case lookup_cached(idempotency_key) do
      {:ok, result} ->
        # キャッシュヒット
        Logger.debug("Idempotency cache hit: #{idempotency_key}")
        new_state = update_in(state, [:stats, :hits], &(&1 + 1))

        :telemetry.execute(
          [:idempotency, :cache_hit],
          %{count: 1},
          %{key: idempotency_key}
        )

        {:reply, {:ok, result}, new_state}

      {:error, :not_found} ->
        # キャッシュミス - 操作を実行
        Logger.debug("Idempotency cache miss: #{idempotency_key}")

        result =
          try do
            operation.()
          rescue
            e ->
              {:error, Exception.format(:error, e, __STACKTRACE__)}
          end

        case result do
          {:ok, value} = success ->
            # 結果をキャッシュ
            cache_result(idempotency_key, value, ttl)

            new_state =
              state
              |> update_in([:stats, :misses], &(&1 + 1))
              |> update_in([:stats, :executions], &(&1 + 1))

            :telemetry.execute(
              [:idempotency, :execution],
              %{count: 1},
              %{key: idempotency_key, status: :success}
            )

            {:reply, success, new_state}

          {:error, _reason} = error ->
            # エラーはキャッシュしない（リトライ可能にするため）
            new_state =
              state
              |> update_in([:stats, :misses], &(&1 + 1))
              |> update_in([:stats, :errors], &(&1 + 1))

            :telemetry.execute(
              [:idempotency, :execution],
              %{count: 1},
              %{key: idempotency_key, status: :error}
            )

            {:reply, error, new_state}

          other ->
            # 予期しない戻り値
            Logger.warning("Unexpected result from idempotent operation: #{inspect(other)}")
            {:reply, {:error, {:unexpected_result, other}}, state}
        end

      {:error, :expired} ->
        # 期限切れ - 再実行
        Logger.debug("Idempotency cache expired: #{idempotency_key}")
        handle_call({:execute, idempotency_key, operation, opts}, :retry, state)
    end
  end

  @impl true
  def handle_call({:get, idempotency_key}, _from, state) do
    result = lookup_cached(idempotency_key)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    db_count = Repo.one(from(i in IdempotencyRecord, select: count(i.id))) || 0
    ets_count = :ets.info(@table_name, :size)

    stats =
      Map.merge(state.stats, %{
        db_records: db_count,
        cache_entries: ets_count
      })

    {:reply, {:ok, stats}, state}
  end

  @impl true
  def handle_cast({:put, idempotency_key, result, opts}, state) do
    ttl = Keyword.get(opts, :ttl, 3600)
    cache_result(idempotency_key, result, ttl)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:delete, idempotency_key}, state) do
    # ETSから削除
    :ets.delete(@table_name, idempotency_key)

    # DBから削除
    from(i in IdempotencyRecord, where: i.key == ^idempotency_key)
    |> Repo.delete_all()

    Logger.debug("Deleted idempotency key: #{idempotency_key}")

    {:noreply, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired()
    schedule_cleanup()
    {:noreply, state}
  end

  # Private functions

  defp lookup_cached(idempotency_key) do
    case :ets.lookup(@table_name, idempotency_key) do
      [{^idempotency_key, result, expires_at}] ->
        if DateTime.compare(expires_at, DateTime.utc_now()) == :gt do
          {:ok, result}
        else
          {:error, :expired}
        end

      [] ->
        # ETSにない場合はDBを確認
        case lookup_db(idempotency_key) do
          {:ok, record} ->
            # ETSにキャッシュして返す
            :ets.insert(@table_name, {idempotency_key, record.result, record.expires_at})
            {:ok, record.result}

          error ->
            error
        end
    end
  end

  defp lookup_db(idempotency_key) do
    now = DateTime.utc_now()

    query =
      from(i in IdempotencyRecord,
        where: i.key == ^idempotency_key and i.expires_at > ^now
      )

    case Repo.one(query) do
      nil -> {:error, :not_found}
      record -> {:ok, record}
    end
  end

  defp cache_result(idempotency_key, result, ttl_seconds) do
    expires_at = DateTime.utc_now() |> DateTime.add(ttl_seconds, :second)

    # ETSに保存
    :ets.insert(@table_name, {idempotency_key, result, expires_at})

    # DBに永続化
    %IdempotencyRecord{}
    |> IdempotencyRecord.changeset(%{
      key: idempotency_key,
      result: result,
      expires_at: expires_at,
      created_at: DateTime.utc_now()
    })
    |> Repo.insert(
      on_conflict: {:replace, [:result, :expires_at, :updated_at]},
      conflict_target: :key
    )
    |> case do
      {:ok, _} ->
        Logger.debug("Cached idempotency result: #{idempotency_key}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to persist idempotency record: #{inspect(reason)}")
        :error
    end
  end

  defp cleanup_expired do
    now = DateTime.utc_now()

    # DBから期限切れレコードを削除
    {count, _} =
      from(i in IdempotencyRecord, where: i.expires_at < ^now)
      |> Repo.delete_all()

    if count > 0 do
      Logger.info("Cleaned up #{count} expired idempotency records")
    end

    # ETSから期限切れエントリを削除
    expired_keys =
      :ets.foldl(
        fn {key, _result, expires_at}, acc ->
          if DateTime.compare(expires_at, now) == :lt do
            [key | acc]
          else
            acc
          end
        end,
        [],
        @table_name
      )

    Enum.each(expired_keys, &:ets.delete(@table_name, &1))
  end

  defp restore_from_db do
    now = DateTime.utc_now()

    query =
      from(i in IdempotencyRecord,
        where: i.expires_at > ^now,
        # 大量のレコードでメモリを圧迫しないよう制限
        limit: 10_000
      )

    records = Repo.all(query)

    Enum.each(records, fn record ->
      :ets.insert(@table_name, {record.key, record.result, record.expires_at})
    end)

    Logger.info("Restored #{length(records)} idempotency records from database")
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval_minutes * 60 * 1000)
  end
end

defmodule Shared.CQRS.QueryDispatcher do
  @moduledoc """
  クエリの動的ディスパッチャー

  プロトコルベースでクエリを適切なハンドラーにルーティングし、
  キャッシング、バリデーション、エラーハンドリングを提供する。
  """

  alias Shared.CQRS.Query
  alias Shared.Infrastructure.Idempotency.IdempotencyStore

  require Logger

  @type dispatch_result :: {:ok, any()} | {:error, any()}
  @type dispatch_opts :: [
          use_cache: boolean(),
          cache_ttl: non_neg_integer(),
          timeout: non_neg_integer(),
          metadata: map()
        ]

  @doc """
  クエリをディスパッチする

  ## Options
  - `:use_cache` - キャッシュを使用する（デフォルト: クエリの設定に従う）
  - `:cache_ttl` - キャッシュTTL（秒）
  - `:timeout` - タイムアウト（ミリ秒）
  - `:metadata` - 追加のメタデータ

  ## Examples
      dispatch(%GetOrderQuery{id: "123"})
      dispatch(%ListProductsQuery{}, use_cache: false)
  """
  @spec dispatch(struct(), dispatch_opts()) :: dispatch_result()
  def dispatch(query, opts \\ []) do
    with :ok <- validate_query(query),
         {:ok, handler} <- get_handler(query) do
      use_cache = Keyword.get(opts, :use_cache, Query.cacheable?(query))

      if use_cache && Query.cacheable?(query) do
        dispatch_with_cache(query, handler, opts)
      else
        dispatch_direct(query, handler, opts)
      end
    end
  end

  @doc """
  クエリを並列でディスパッチする

  複数のクエリを同時に実行し、すべての結果を待つ。
  """
  @spec dispatch_parallel([struct()], dispatch_opts()) :: {:ok, [any()]} | {:error, any()}
  def dispatch_parallel(queries, opts \\ []) do
    # すべてのクエリをバリデート
    with :ok <- validate_all_queries(queries) do
      # 並列実行
      tasks =
        Enum.map(queries, fn query ->
          Task.async(fn ->
            case dispatch(query, opts) do
              {:ok, result} -> {:ok, {query, result}}
              {:error, reason} -> {:error, {query, reason}}
            end
          end)
        end)

      # タイムアウトを設定
      timeout = Keyword.get(opts, :timeout, 30_000)

      # 結果を収集
      results = Task.await_many(tasks, timeout)

      # エラーがあれば全体を失敗とする
      errors = Enum.filter(results, &match?({:error, _}, &1))

      if Enum.empty?(errors) do
        {:ok, Enum.map(results, fn {:ok, {_query, result}} -> result end)}
      else
        {:error, {:parallel_query_failed, errors}}
      end
    end
  end

  @doc """
  キャッシュをクリアする

  特定のクエリタイプのキャッシュをクリアする。
  """
  @spec clear_cache(atom()) :: :ok
  def clear_cache(entity_type) do
    # TODO: キャッシュクリアの実装
    Logger.info("Clearing cache for entity type: #{entity_type}")
    :ok
  end

  # Private functions

  defp validate_query(query) do
    try do
      case Query.validate(query) do
        :ok -> :ok
        {:error, _} = error -> error
      end
    rescue
      Protocol.UndefinedError ->
        {:error, {:invalid_query, "Query must implement Shared.CQRS.Query protocol"}}
    end
  end

  defp validate_all_queries(queries) do
    errors =
      queries
      |> Enum.with_index()
      |> Enum.reduce([], fn {query, index}, acc ->
        case validate_query(query) do
          :ok -> acc
          {:error, reason} -> [{index, reason} | acc]
        end
      end)

    if Enum.empty?(errors) do
      :ok
    else
      {:error, {:validation_failed, Enum.reverse(errors)}}
    end
  end

  defp get_handler(query) do
    try do
      handler = Query.handler(query)

      # ハンドラーが存在することを確認
      if Code.ensure_loaded?(handler) do
        {:ok, handler}
      else
        {:error, {:handler_not_found, handler}}
      end
    rescue
      Protocol.UndefinedError ->
        {:error, {:invalid_query, "Query must implement Shared.CQRS.Query protocol"}}
    end
  end

  defp dispatch_with_cache(query, handler, opts) do
    cache_key = Query.cache_key(query)

    if cache_key do
      # デフォルト5分
      ttl = Keyword.get(opts, :cache_ttl, 300)

      IdempotencyStore.execute(
        cache_key,
        fn ->
          dispatch_direct(query, handler, opts)
        end,
        ttl: ttl
      )
    else
      dispatch_direct(query, handler, opts)
    end
  end

  defp dispatch_direct(query, handler, opts) do
    start_time = System.monotonic_time()

    # メタデータを準備
    metadata = prepare_metadata(query, opts)

    # Telemetryイベントを発行
    :telemetry.execute(
      [:cqrs, :query, :dispatching],
      %{},
      metadata
    )

    # ハンドラーを実行
    result =
      try do
        if function_exported?(handler, :handle, 2) do
          handler.handle(query, metadata)
        else
          handler.handle(query)
        end
      rescue
        e ->
          Logger.error("Query handler raised an exception: #{inspect(e)}")
          {:error, {:handler_exception, e, __STACKTRACE__}}
      end

    # 実行時間を計測
    duration = System.monotonic_time() - start_time

    # 結果に応じたTelemetryイベントを発行
    case result do
      {:ok, _} = success ->
        :telemetry.execute(
          [:cqrs, :query, :success],
          %{duration: System.convert_time_unit(duration, :native, :millisecond)},
          metadata
        )

        success

      {:error, _} = error ->
        :telemetry.execute(
          [:cqrs, :query, :failure],
          %{duration: System.convert_time_unit(duration, :native, :millisecond)},
          Map.put(metadata, :error, elem(error, 1))
        )

        error

      other ->
        # 予期しない戻り値
        Logger.warning("Query handler returned unexpected value: #{inspect(other)}")
        {:error, {:invalid_handler_response, other}}
    end
  end

  defp prepare_metadata(query, opts) do
    %{
      query_type: query.__struct__,
      entity_type: Query.entity_type(query),
      cacheable: Query.cacheable?(query),
      cache_key: Query.cache_key(query),
      timestamp: DateTime.utc_now(),
      user_metadata: Keyword.get(opts, :metadata, %{})
    }
  end
end

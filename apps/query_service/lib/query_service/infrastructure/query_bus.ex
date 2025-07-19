defmodule QueryService.Infrastructure.QueryBus do
  @moduledoc """
  クエリバス

  クエリを適切なハンドラーにルーティングし、実行します。
  """

  use GenServer
  require Logger

  @type query :: struct()
  @type handler :: module()
  @type result :: {:ok, any()} | {:error, any()}

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  クエリを実行する
  """
  @spec execute(query()) :: result()
  def execute(query) do
    GenServer.call(__MODULE__, {:execute, query})
  end

  @doc """
  クエリをディスパッチする（executeのエイリアス）
  """
  @spec dispatch(query()) :: result()
  def dispatch(query), do: execute(query)

  @doc """
  ハンドラーを登録する
  """
  @spec register_handler(String.t(), handler()) :: :ok
  def register_handler(query_type, handler) do
    GenServer.call(__MODULE__, {:register_handler, query_type, handler})
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    state = %{
      handlers: %{
        # クエリタイプとハンドラーのマッピング
        "category.list" => QueryService.Application.Handlers.CategoryQueryHandler,
        "category.get" => QueryService.Application.Handlers.CategoryQueryHandler,
        "category.get_by_id" => QueryService.Application.Handlers.CategoryQueryHandler,
        "category.get_all" => QueryService.Application.Handlers.CategoryQueryHandler,
        "category.search" => QueryService.Application.Handlers.CategoryQueryHandler,
        "product.list" => QueryService.Application.Handlers.ProductQueryHandler,
        "product.get" => QueryService.Application.Handlers.ProductQueryHandler,
        "product.get_by_id" => QueryService.Application.Handlers.ProductQueryHandler,
        "product.get_all" => QueryService.Application.Handlers.ProductQueryHandler,
        "product.get_by_category" => QueryService.Application.Handlers.ProductQueryHandler,
        "product.search" => QueryService.Application.Handlers.ProductQueryHandler,
        "order.list" => QueryService.Application.Handlers.OrderQueryHandler,
        "order.get" => QueryService.Application.Handlers.OrderQueryHandler,
        "order.get_by_id" => QueryService.Application.Handlers.OrderQueryHandler,
        "order.get_by_user" => QueryService.Application.Handlers.OrderQueryHandler,
        "order.search" => QueryService.Application.Handlers.OrderQueryHandler
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:execute, query}, _from, state) do
    result = execute_query(query, state.handlers)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:register_handler, query_type, handler}, _from, state) do
    new_handlers = Map.put(state.handlers, query_type, handler)
    {:reply, :ok, %{state | handlers: new_handlers}}
  end

  # Private functions

  defp execute_query(query, handlers) do
    query_type = get_query_type(query)

    case Map.get(handlers, query_type) do
      nil ->
        Logger.error("No handler registered for query type: #{query_type}")
        {:error, :handler_not_found}

      handler ->
        try do
          Logger.info("Executing query: #{query_type}")
          # マップ形式のクエリを構造体に変換
          struct_query = convert_to_struct(query)
          handler.handle(struct_query)
        rescue
          error ->
            Logger.error("Error executing query: #{inspect(error)}")
            {:error, :execution_failed}
        end
    end
  end

  defp get_query_type(query) do
    cond do
      # query_type フィールドがある場合は直接使用
      Map.has_key?(query, :query_type) ->
        query.query_type

      # __struct__ がアトムの場合
      is_atom(Map.get(query, :__struct__)) and
          function_exported?(query.__struct__, :query_type, 0) ->
        query.__struct__.query_type()

      # __struct__ が文字列の場合（PubSub経由）
      is_binary(Map.get(query, :__struct__)) ->
        # 文字列からモジュール名を推測
        query.__struct__
        |> String.split(".")
        |> List.last()
        |> Macro.underscore()

      true ->
        # モジュール名から推測
        query.__struct__
        |> Module.split()
        |> List.last()
        |> Macro.underscore()
    end
  end

  defp convert_to_struct(query) when is_struct(query), do: query

  defp convert_to_struct(query) when is_map(query) do
    case Map.get(query, :__struct__) do
      nil ->
        query

      struct_name when is_binary(struct_name) ->
        # 文字列のモジュール名をアトムに変換
        try do
          module = String.to_existing_atom(struct_name)
          # マップから構造体を再構築
          query
          |> Map.delete(:__struct__)
          |> then(&struct(module, &1))
        rescue
          _ ->
            # エラーが発生した場合は、各フィールドを明示的に設定
            case struct_name do
              "QueryService.Application.Queries.CategoryQueries.GetCategory" ->
                %QueryService.Application.Queries.CategoryQueries.GetCategory{
                  id: Map.get(query, :id),
                  metadata: Map.get(query, :metadata)
                }

              "QueryService.Application.Queries.CategoryQueries.ListCategories" ->
                %QueryService.Application.Queries.CategoryQueries.ListCategories{
                  limit: Map.get(query, :limit, 20),
                  offset: Map.get(query, :offset, 0),
                  sort_by: Map.get(query, :sort_by),
                  sort_order: Map.get(query, :sort_order),
                  metadata: Map.get(query, :metadata)
                }

              "QueryService.Application.Queries.ProductQueries.GetProduct" ->
                %QueryService.Application.Queries.ProductQueries.GetProduct{
                  id: Map.get(query, :id),
                  metadata: Map.get(query, :metadata)
                }

              "QueryService.Application.Queries.ProductQueries.ListProducts" ->
                %QueryService.Application.Queries.ProductQueries.ListProducts{
                  category_id: Map.get(query, :category_id),
                  limit: Map.get(query, :limit, 20),
                  offset: Map.get(query, :offset, 0),
                  sort_by: Map.get(query, :sort_by),
                  sort_order: Map.get(query, :sort_order),
                  metadata: Map.get(query, :metadata)
                }

              "QueryService.Application.Queries.ProductQueries.SearchProducts" ->
                %QueryService.Application.Queries.ProductQueries.SearchProducts{
                  search_term: Map.get(query, :search_term),
                  category_id: Map.get(query, :category_id),
                  limit: Map.get(query, :limit, 20),
                  offset: Map.get(query, :offset, 0),
                  metadata: Map.get(query, :metadata)
                }

              _ ->
                query
            end
        end

      struct_name when is_atom(struct_name) ->
        query
    end
  end
end

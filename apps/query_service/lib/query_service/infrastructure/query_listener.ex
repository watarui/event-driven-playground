defmodule QueryService.Infrastructure.QueryListener do
  @moduledoc """
  クエリリスナー

  PubSub からクエリを受信し、QueryBus で処理してレスポンスを返します。
  """

  use GenServer

  alias Shared.Config
  alias QueryService.Infrastructure.QueryBus

  require Logger

  @query_topic :"query-requests"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # クエリトピックを購読（raw メソッドを使用）
    event_bus_module = Config.event_bus_module()
    event_bus_module.subscribe_raw(@query_topic)

    # 本番環境では Cloud Pub/Sub も購読
    if should_use_cloud_pubsub?() do
      Shared.Infrastructure.PubSub.CloudPubSubClient.subscribe("query-requests", __MODULE__)
    end

    Logger.info(
      "QueryListener started and subscribed to queries using #{inspect(event_bus_module)}"
    )

    {:ok, %{event_bus: event_bus_module}}
  end

  @impl true
  def handle_info({:event, message}, state) when is_map(message) do
    # 非同期でクエリを処理
    Task.start(fn ->
      process_query(message, state.event_bus)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp process_query(%{request_id: request_id, query: query, reply_to: reply_to}, event_bus) do
    result =
      case query do
        # 文字列の場合はエラー
        query_string when is_binary(query_string) ->
          Logger.error("Received query as string instead of struct: #{query_string}")
          {:error, "Query must be a struct or map, not a string"}

        # 構造体の場合はそのまま処理
        query_struct when is_struct(query_struct) ->
          Logger.debug("Processing query struct: #{inspect(query_struct.__struct__)}")
          QueryBus.dispatch(query_struct)

        # マップの場合は query_type に基づいて構造体を生成
        %{query_type: query_type} = query_map when is_map(query_map) ->
          Logger.debug("Processing query map with type: #{query_type}")
          process_query_map(query_type, query_map)

        _ ->
          Logger.error("Invalid query type: #{inspect(query)}")
          {:error, "Invalid query type"}
      end

    # レスポンスを作成
    response = %{
      request_id: request_id,
      result: result,
      timestamp: DateTime.utc_now()
    }

    # レスポンスを返信
    event_bus.publish_raw(reply_to, response)
  rescue
    error ->
      Logger.error("Error processing query: #{inspect(error)}")

      # エラーレスポンスを返信
      response = %{
        request_id: request_id,
        result: {:error, "Query processing failed: #{inspect(error)}"},
        timestamp: DateTime.utc_now()
      }

      event_bus.publish_raw(reply_to, response)
  end

  defp process_query_map(query_type, query_map) do
    # query_type からモジュール名を決定
    case resolve_query_module(query_type) do
      {:ok, module} ->
        # マップからquery_typeを除去してvalidate関数に渡す
        params = Map.delete(query_map, :query_type)

        case module.validate(params) do
          {:ok, query_struct} ->
            QueryBus.dispatch(query_struct)

          {:error, reason} ->
            {:error, "Query validation failed: #{reason}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_query_module(query_type) do
    # query_type に基づいてモジュールを解決
    query_modules = %{
      "category.list" => QueryService.Application.Queries.CategoryQueries.ListCategories,
      "category.get" => QueryService.Application.Queries.CategoryQueries.GetCategory,
      "category.search" => QueryService.Application.Queries.CategoryQueries.SearchCategories,
      "product.list" => QueryService.Application.Queries.ProductQueries.ListProducts,
      "product.get" => QueryService.Application.Queries.ProductQueries.GetProduct,
      "product.search" => QueryService.Application.Queries.ProductQueries.SearchProducts,
      "order.list" => QueryService.Application.Queries.OrderQueries.ListOrders,
      "order.get" => QueryService.Application.Queries.OrderQueries.GetOrder
    }

    case Map.get(query_modules, query_type) do
      nil -> {:error, "Unknown query type: #{query_type}"}
      module -> {:ok, module}
    end
  end

  @doc """
  Cloud Pub/Sub からのメッセージを処理
  """
  def handle_cloud_pubsub_message(topic, message) do
    Logger.info("QueryListener received Cloud Pub/Sub message on #{topic}: #{inspect(message)}")
    
    # GenServer にメッセージを転送
    send(__MODULE__, {:event, message})
  end

  defp should_use_cloud_pubsub? do
    System.get_env("MIX_ENV") == "prod" && 
    System.get_env("GOOGLE_CLOUD_PROJECT") != nil &&
    System.get_env("FORCE_LOCAL_PUBSUB") != "true"
  end
end

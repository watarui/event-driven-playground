defmodule QueryService.Application.Handlers.OrderQueryHandler do
  @moduledoc """
  注文クエリハンドラー

  注文に関するクエリを処理します。
  """

  alias QueryService.Infrastructure.Repositories.OrderRepository

  require Logger

  @doc """
  クエリを処理する
  """
  # 構造体を受け取るパターン
  def handle(%QueryService.Application.Queries.OrderQueries.GetOrder{id: id}) do
    Logger.info("Getting order by id: #{id}")
    OrderRepository.get(id)
  end

  def handle(%QueryService.Application.Queries.OrderQueries.ListOrders{} = query) do
    Logger.info("Listing orders")

    filters = %{
      limit: query.limit || 20,
      offset: query.offset || 0,
      sort_by: query.sort_by || "created_at",
      sort_order: query.sort_order || :desc
    }

    OrderRepository.get_all(filters)
  end

  # マップ形式のクエリも受け取る（後方互換性）
  def handle(%{query_type: "order.get", id: id}) do
    Logger.info("Getting order by id: #{id}")
    OrderRepository.get(id)
  end

  def handle(%{query_type: "order.get_by_id", id: id}) do
    Logger.info("Getting order by id: #{id}")
    OrderRepository.get(id)
  end

  def handle(%{query_type: "order.get_by_user", user_id: user_id} = query) do
    Logger.info("Getting orders by user: #{user_id}")

    filters =
      %{user_id: user_id}
      |> maybe_add_filter(:status, Map.get(query, :status))
      |> maybe_add_filter(:limit, Map.get(query, :limit))
      |> maybe_add_filter(:offset, Map.get(query, :offset))

    OrderRepository.get_all(filters)
  end

  def handle(%{query_type: "order.list_by_user", user_id: user_id} = query) do
    Logger.info("Listing orders by user: #{user_id}")

    filters =
      %{user_id: user_id}
      |> maybe_add_filter(:status, Map.get(query, :status))
      |> maybe_add_filter(:limit, Map.get(query, :limit))
      |> maybe_add_filter(:offset, Map.get(query, :offset))

    OrderRepository.get_all(filters)
  end

  def handle(%{query_type: "order.list"} = query) do
    Logger.info("Listing orders")

    filters =
      %{}
      |> maybe_add_filter(:user_id, Map.get(query, :user_id))
      |> maybe_add_filter(:status, Map.get(query, :status))
      |> maybe_add_filter(:limit, Map.get(query, :limit, 20))
      |> maybe_add_filter(:offset, Map.get(query, :offset, 0))

    OrderRepository.get_all(filters)
  end

  def handle(%{query_type: "order.search"} = query) do
    Logger.info("Searching orders")

    filters = build_search_filters(query)
    OrderRepository.search(filters)
  end

  # Private functions

  defp build_search_filters(query) do
    %{}
    |> maybe_add_filter(:user_id, Map.get(query, :user_id))
    |> maybe_add_filter(:status, Map.get(query, :status))
    |> maybe_add_filter(:from_date, Map.get(query, :from_date))
    |> maybe_add_filter(:to_date, Map.get(query, :to_date))
    |> maybe_add_filter(:min_amount, Map.get(query, :min_amount))
    |> maybe_add_filter(:max_amount, Map.get(query, :max_amount))
    |> maybe_add_filter(:limit, Map.get(query, :limit))
    |> maybe_add_filter(:offset, Map.get(query, :offset))
  end

  defp maybe_add_filter(filters, _key, nil), do: filters
  defp maybe_add_filter(filters, key, value), do: Map.put(filters, key, value)
end

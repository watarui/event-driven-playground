defmodule QueryService.Application.Handlers.ProductQueryHandler do
  @moduledoc """
  商品クエリハンドラー

  商品に関するクエリを処理します。
  """

  alias QueryService.Infrastructure.Repositories.ProductRepository
  alias QueryService.Application.Queries.ProductQueries
  alias QueryService.Infrastructure.Cache

  require Logger

  @doc """
  クエリを処理する
  """
  def handle(%ProductQueries.GetProduct{id: id}) do
    Logger.info("Getting product by id: #{id}")

    cache_key = "product:#{id}"

    Cache.fetch(cache_key, fn ->
      ProductRepository.get(id)
    end)
  end

  def handle(%ProductQueries.ListProducts{} = query) do
    Logger.info("Getting products")

    filters = build_filters(query)
    cache_key = "products:list:#{:erlang.phash2(filters)}"

    Cache.fetch(
      cache_key,
      fn ->
        ProductRepository.get_all(filters)
      end,
      :timer.minutes(1)
    )
  end

  def handle(%ProductQueries.SearchProducts{search_term: search_term} = query) do
    Logger.info("Searching products with search term: #{search_term}")

    filters = build_filters(query)
    ProductRepository.search(search_term, filters)
  end

  # Private functions

  defp build_filters(query) do
    %{}
    |> maybe_add_filter(:active, Map.get(query, :active))
    |> maybe_add_filter(:sort_by, Map.get(query, :sort_by))
    |> maybe_add_filter(:sort_order, Map.get(query, :sort_order))
    |> maybe_add_filter(:limit, Map.get(query, :limit))
    |> maybe_add_filter(:offset, Map.get(query, :offset))
  end

  defp maybe_add_filter(filters, _key, nil), do: filters
  defp maybe_add_filter(filters, key, value), do: Map.put(filters, key, value)
end

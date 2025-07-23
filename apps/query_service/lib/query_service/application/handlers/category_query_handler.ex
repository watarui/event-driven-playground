defmodule QueryService.Application.Handlers.CategoryQueryHandler do
  @moduledoc """
  カテゴリクエリハンドラー

  カテゴリに関するクエリを処理します。
  """

  alias QueryService.Infrastructure.Repositories.CategoryRepository
  alias QueryService.Application.Queries.CategoryQueries

  require Logger

  @doc """
  クエリを処理する
  """
  def handle(%CategoryQueries.GetCategory{id: id}) do
    Logger.info("Getting category by id: #{id}")
    CategoryRepository.get(id)
  end

  def handle(%CategoryQueries.ListCategories{} = query) do
    Logger.info("Getting all categories")

    filters = build_filters(query)
    CategoryRepository.get_all(filters)
  end

  # マップ形式のクエリも受け取る（後方互換性）
  def handle(%{query_type: "category.get", id: id}) do
    Logger.info("Getting category by id: #{id}")
    CategoryRepository.get(id)
  end

  def handle(%{query_type: "category.list"} = query) do
    Logger.info("Getting all categories")

    filters = %{
      limit: Map.get(query, :limit, 20),
      offset: Map.get(query, :offset, 0)
    }

    CategoryRepository.get_all(filters)
  end

  def handle(%{query_type: "category.search"} = query) do
    Logger.info("Searching categories")

    filters = %{
      search: Map.get(query, :query, ""),
      limit: Map.get(query, :limit, 20),
      offset: Map.get(query, :offset, 0)
    }

    CategoryRepository.get_all(filters)
  end

  # Private functions

  defp build_filters(query) do
    %{}
    |> maybe_add_filter(:limit, Map.get(query, :limit))
    |> maybe_add_filter(:offset, Map.get(query, :offset))
    |> maybe_add_filter(:sort_by, Map.get(query, :sort_by))
    |> maybe_add_filter(:sort_order, Map.get(query, :sort_order))
  end

  defp maybe_add_filter(filters, _key, nil), do: filters
  defp maybe_add_filter(filters, key, value), do: Map.put(filters, key, value)
end

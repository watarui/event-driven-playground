defmodule ClientService.GraphQL.Dataloader do
  @moduledoc """
  GraphQL 用のデータローダー

  N+1 問題を解決し、効率的なデータ取得を実現します
  """

  alias Shared.Infrastructure.EventBus

  require Logger

  @doc """
  Dataloader を作成する
  """
  def new do
    Dataloader.new()
    |> Dataloader.add_source(:query_service, data_source())
  end

  @doc """
  コンテキストに dataloader を追加する
  """
  def context(ctx) do
    Map.put(ctx, :loader, new())
  end

  @doc """
  Dataloader を実行する
  """
  def run(ctx) do
    case Map.get(ctx, :loader) do
      nil ->
        ctx

      loader ->
        Map.put(ctx, :loader, Dataloader.run(loader))
    end
  end

  # Private functions

  defp data_source do
    Dataloader.KV.new(&fetch/2)
  end

  defp fetch({:products, _args}, category_ids) do
    # カテゴリIDのリストから商品を一括取得
    products = batch_get_products_by_categories(category_ids)

    # カテゴリID別にグループ化
    Map.new(category_ids, fn category_id ->
      {category_id, Map.get(products, category_id, [])}
    end)
  end

  defp fetch(:category, product_category_ids) do
    # カテゴリIDのリストからカテゴリを一括取得
    categories = batch_get_categories(product_category_ids)

    # カテゴリIDをキーとするマップを作成
    Map.new(product_category_ids, fn category_id ->
      {category_id, Map.get(categories, category_id)}
    end)
  end

  defp fetch(:product, product_ids) do
    # 商品IDのリストから商品を一括取得
    products = batch_get_products(product_ids)

    # 商品IDをキーとするマップを作成
    Map.new(product_ids, fn product_id ->
      {product_id, Map.get(products, product_id)}
    end)
  end

  defp batch_get_products_by_categories(category_ids) do
    Logger.debug("Batch loading products for categories: #{inspect(category_ids)}")

    query = %{
      type: "get_products_by_categories",
      category_ids: category_ids
    }

    case send_query(query) do
      {:ok, products} ->
        # カテゴリID別にグループ化
        Enum.group_by(products, & &1.category_id)

      {:error, reason} ->
        Logger.error("Failed to load products: #{inspect(reason)}")
        %{}
    end
  end

  defp batch_get_categories(category_ids) do
    Logger.debug("Batch loading categories: #{inspect(category_ids)}")

    # 重複を削除
    unique_ids = Enum.uniq(category_ids)

    query = %{
      type: "get_categories_by_ids",
      ids: unique_ids
    }

    case send_query(query) do
      {:ok, categories} ->
        # IDをキーとするマップを作成
        Map.new(categories, fn category ->
          {category.id, category}
        end)

      {:error, reason} ->
        Logger.error("Failed to load categories: #{inspect(reason)}")
        %{}
    end
  end

  defp batch_get_products(product_ids) do
    Logger.debug("Batch loading products: #{inspect(product_ids)}")

    # 重複を削除
    unique_ids = Enum.uniq(product_ids)

    query = %{
      type: "get_products_by_ids",
      ids: unique_ids
    }

    case send_query(query) do
      {:ok, products} ->
        # IDをキーとするマップを作成
        Map.new(products, fn product ->
          {product.id, product}
        end)

      {:error, reason} ->
        Logger.error("Failed to load products: #{inspect(reason)}")
        %{}
    end
  end

  defp send_query(query) do
    node_name = node()
    response_topic = "query_responses_#{node_name}"

    # クエリを送信
    EventBus.publish(:queries, %{
      query: query,
      reply_to: response_topic,
      request_id: UUID.uuid4()
    })

    # レスポンスを待つ
    receive do
      {:query_response, %{result: result}} ->
        result
    after
      5_000 ->
        {:error, :timeout}
    end
  end
end

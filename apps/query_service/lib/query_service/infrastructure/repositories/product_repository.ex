defmodule QueryService.Infrastructure.Repositories.ProductRepository do
  @moduledoc """
  商品読み取りモデルのリポジトリ実装（Firestore版）
  """

  alias QueryService.Domain.Models.Product
  alias Shared.Infrastructure.Firestore.Repository
  require Logger

  @collection "read_products"

  @doc """
  商品を保存する（プロジェクション用）
  """
  def save(%Product{} = product) do
    data = %{
      id: product.id,
      name: product.name,
      description: product.description,
      price: Decimal.to_float(product.price),
      currency: product.currency || "JPY",
      stock_quantity: product.stock_quantity,
      category_id: product.category_id,
      category_name: product.category_name,
      active: product.active,
      created_at: product.created_at,
      updated_at: DateTime.utc_now()
    }

    case Repository.save(@collection, product.id, data) do
      {:ok, _} -> {:ok, product}
      error -> error
    end
  end

  @doc """
  ID で商品を取得する
  """
  def get(id) do
    case Repository.get(@collection, id) do
      {:ok, data} ->
        product = build_product_from_data(data)
        {:ok, product}

      error ->
        error
    end
  end

  @doc """
  商品を検索する
  """
  def get_all(filters \\ %{}) do
    opts = build_query_opts(filters)

    case Repository.list(@collection, opts) do
      {:ok, data_list} ->
        products = Enum.map(data_list, &build_product_from_data/1)

        # フィルタリング（Firestore クエリが完全でない場合の補完）
        filtered = apply_filters(products, filters)

        # ソート処理
        sorted = apply_sorting(filtered, filters)

        {:ok, sorted}

      error ->
        error
    end
  end

  @doc """
  商品を削除する
  """
  def delete(id) do
    Repository.delete(@collection, id)
  end

  @doc """
  カテゴリーIDで商品を検索する
  """
  def find_by_category(category_id) do
    # TODO: Firestore のクエリ機能を使用して最適化
    case get_all(%{category_id: category_id}) do
      {:ok, products} -> {:ok, products}
      error -> error
    end
  end

  @doc """
  在庫を更新する
  """
  def update_stock(product_id, new_quantity) do
    with {:ok, product} <- get(product_id) do
      updated_product = %{product | stock_quantity: new_quantity}
      save(updated_product)
    end
  end

  @doc """
  カテゴリー名を更新する
  """
  def update_category_name(category_id, new_name) do
    # カテゴリーIDに該当する全商品のカテゴリー名を更新
    case find_by_category(category_id) do
      {:ok, products} ->
        Enum.each(products, fn product ->
          updated_product = %{product | category_name: new_name}
          save(updated_product)
        end)

        {:ok, length(products)}

      error ->
        error
    end
  end

  @doc """
  すべてのプロジェクションをクリアする
  """
  def clear_all do
    # TODO: バッチ削除の実装
    case get_all() do
      {:ok, products} ->
        Enum.each(products, fn product ->
          delete(product.id)
        end)

        {:ok, length(products)}

      error ->
        error
    end
  end

  @doc """
  商品を作成する
  """
  def create(attrs) do
    product = struct(Product, attrs)
    save(product)
  end

  @doc """
  商品を更新する
  """
  def update(id, attrs) do
    with {:ok, product} <- get(id) do
      updated = struct(product, attrs)
      save(updated)
    end
  end

  @doc """
  すべて削除（delete_all）
  """
  def delete_all do
    clear_all()
  end

  @doc """
  検索（search）
  """
  def search(search_term, filters \\ %{}) do
    updated_filters = Map.put(filters, :search, search_term)
    get_all(updated_filters)
  end

  # Private functions

  defp build_product_from_data(data) do
    %Product{
      id: data["id"] || data[:id],
      name: data["name"] || data[:name],
      description: data["description"] || data[:description],
      price: parse_decimal(data["price"] || data[:price]),
      currency: data["currency"] || data[:currency] || "JPY",
      stock_quantity: data["stock_quantity"] || data[:stock_quantity] || 0,
      category_id: data["category_id"] || data[:category_id],
      category_name: data["category_name"] || data[:category_name],
      active: data["active"] || data[:active] || true,
      created_at: parse_datetime(data["created_at"] || data[:created_at]),
      updated_at: parse_datetime(data["updated_at"] || data[:updated_at])
    }
  end

  defp build_query_opts(filters) do
    opts = []

    # ページネーション
    opts = if Map.has_key?(filters, :limit), do: [{:limit, filters.limit} | opts], else: opts
    opts = if Map.has_key?(filters, :offset), do: [{:offset, filters.offset} | opts], else: opts

    opts
  end

  defp apply_filters(products, filters) do
    products
    |> filter_by_category(filters[:category_id])
    |> filter_by_price_range(filters[:min_price], filters[:max_price])
    |> filter_by_stock(filters[:in_stock])
    |> filter_by_search(filters[:search])
  end

  defp filter_by_category(products, nil), do: products

  defp filter_by_category(products, category_id) do
    Enum.filter(products, fn product ->
      product.category_id == category_id
    end)
  end

  defp filter_by_price_range(products, nil, nil), do: products

  defp filter_by_price_range(products, min_price, nil) do
    min = Decimal.new(min_price)

    Enum.filter(products, fn product ->
      Decimal.compare(product.price, min) in [:gt, :eq]
    end)
  end

  defp filter_by_price_range(products, nil, max_price) do
    max = Decimal.new(max_price)

    Enum.filter(products, fn product ->
      Decimal.compare(product.price, max) in [:lt, :eq]
    end)
  end

  defp filter_by_price_range(products, min_price, max_price) do
    products
    |> filter_by_price_range(min_price, nil)
    |> filter_by_price_range(nil, max_price)
  end

  defp filter_by_stock(products, nil), do: products

  defp filter_by_stock(products, true) do
    Enum.filter(products, fn product ->
      product.stock_quantity > 0
    end)
  end

  defp filter_by_stock(products, false), do: products

  defp filter_by_search(products, nil), do: products

  defp filter_by_search(products, search_term) do
    term = String.downcase(search_term)

    Enum.filter(products, fn product ->
      String.contains?(String.downcase(product.name), term) ||
        (product.description && String.contains?(String.downcase(product.description), term))
    end)
  end

  defp apply_sorting(products, %{sort_by: field, sort_order: order}) do
    Enum.sort_by(products, &Map.get(&1, field), order_to_fun(order))
  end

  defp apply_sorting(products, _), do: products

  defp order_to_fun(:asc), do: &<=/2
  defp order_to_fun(:desc), do: &>=/2
  defp order_to_fun(_), do: &<=/2

  defp parse_decimal(nil), do: Decimal.new(0)
  defp parse_decimal(value) when is_float(value), do: Decimal.from_float(value)
  defp parse_decimal(value) when is_integer(value), do: Decimal.new(value)

  defp parse_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, _} -> decimal
      :error -> Decimal.new(0)
    end
  end

  defp parse_decimal(_), do: Decimal.new(0)

  defp parse_datetime(nil), do: nil
  defp parse_datetime(%DateTime{} = dt), do: dt

  defp parse_datetime(string) when is_binary(string) do
    case DateTime.from_iso8601(string) do
      {:ok, datetime, _} -> datetime
      _ -> nil
    end
  end

  defp parse_datetime(_), do: nil
end

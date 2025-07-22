defmodule CommandService.Infrastructure.Repositories.ProductRepository do
  @moduledoc """
  商品エンティティのリポジトリ実装（Firestore版）
  """

  alias CommandService.Domain.Models.Product
  alias Shared.Infrastructure.Firestore.Repository

  @collection "products"

  @doc """
  商品を保存する
  """
  def save(%Product{} = product) do
    data = %{
      id: product.id,
      name: product.name,
      description: product.description,
      price: Decimal.to_float(product.price),
      stock_quantity: product.stock_quantity,
      category_id: product.category_id,
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
        product = %Product{
          id: data["id"] || data[:id],
          name: data["name"] || data[:name],
          description: data["description"] || data[:description],
          price: parse_decimal(data["price"] || data[:price]),
          stock_quantity: data["stock_quantity"] || data[:stock_quantity] || 0,
          category_id: data["category_id"] || data[:category_id],
          created_at: parse_datetime(data["created_at"] || data[:created_at]),
          updated_at: parse_datetime(data["updated_at"] || data[:updated_at])
        }

        {:ok, product}

      error ->
        error
    end
  end

  @doc """
  すべての商品を取得する
  """
  def get_all(opts \\ []) do
    case Repository.list(@collection, opts) do
      {:ok, data_list} ->
        products =
          Enum.map(data_list, fn data ->
            %Product{
              id: data["id"] || data[:id],
              name: data["name"] || data[:name],
              description: data["description"] || data[:description],
              price: parse_decimal(data["price"] || data[:price]),
              stock_quantity: data["stock_quantity"] || data[:stock_quantity] || 0,
              category_id: data["category_id"] || data[:category_id],
              created_at: parse_datetime(data["created_at"] || data[:created_at]),
              updated_at: parse_datetime(data["updated_at"] || data[:updated_at])
            }
          end)

        {:ok, products}

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
    # TODO: Firestore のクエリ機能を使用して実装
    # 一時的に全件取得してフィルタリング
    case get_all() do
      {:ok, products} ->
        filtered =
          Enum.filter(products, fn product ->
            product.category_id == category_id
          end)

        {:ok, filtered}

      error ->
        error
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
  在庫を減らす
  """
  def decrement_stock(product_id, quantity) do
    with {:ok, product} <- get(product_id),
         new_quantity when new_quantity >= 0 <- product.stock_quantity - quantity do
      update_stock(product_id, new_quantity)
    else
      _ -> {:error, :insufficient_stock}
    end
  end

  @doc """
  在庫を増やす
  """
  def increment_stock(product_id, quantity) do
    with {:ok, product} <- get(product_id) do
      update_stock(product_id, product.stock_quantity + quantity)
    end
  end

  # Private functions

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

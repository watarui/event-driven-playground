defmodule QueryService.Infrastructure.Repositories.CategoryRepository do
  @moduledoc """
  カテゴリー読み取りモデルのリポジトリ実装（Firestore版）
  """

  alias QueryService.Domain.Models.Category
  alias Shared.Infrastructure.Firestore.Repository

  @collection "read_categories"

  @doc """
  カテゴリーを保存する（プロジェクション用）
  """
  def save(%Category{} = category) do
    data = %{
      id: category.id,
      name: category.name,
      description: category.description,
      product_count: category.product_count || 0,
      created_at: category.created_at,
      updated_at: DateTime.utc_now()
    }

    case Repository.save(@collection, category.id, data) do
      {:ok, _} -> {:ok, category}
      error -> error
    end
  end

  @doc """
  ID でカテゴリーを取得する
  """
  def get(id) do
    case Repository.get(@collection, id) do
      {:ok, data} -> 
        category = %Category{
          id: data["id"] || data[:id],
          name: data["name"] || data[:name],
          description: data["description"] || data[:description],
          product_count: data["product_count"] || data[:product_count] || 0,
          created_at: parse_datetime(data["created_at"] || data[:created_at]),
          updated_at: parse_datetime(data["updated_at"] || data[:updated_at])
        }
        {:ok, category}
      
      error -> 
        error
    end
  end

  @doc """
  すべてのカテゴリーを取得する
  """
  def get_all(filters \\ %{}) do
    opts = build_query_opts(filters)
    
    case Repository.list(@collection, opts) do
      {:ok, data_list} ->
        categories = Enum.map(data_list, fn data ->
          %Category{
            id: data["id"] || data[:id],
            name: data["name"] || data[:name],
            description: data["description"] || data[:description],
            product_count: data["product_count"] || data[:product_count] || 0,
            created_at: parse_datetime(data["created_at"] || data[:created_at]),
            updated_at: parse_datetime(data["updated_at"] || data[:updated_at])
          }
        end)
        
        # ソート処理
        sorted = apply_sorting(categories, filters)
        
        {:ok, sorted}
      
      error -> 
        error
    end
  end

  @doc """
  カテゴリーを削除する
  """
  def delete(id) do
    Repository.delete(@collection, id)
  end

  @doc """
  商品数を更新する
  """
  def update_product_count(category_id, count) do
    with {:ok, category} <- get(category_id) do
      updated_category = %{category | product_count: count}
      save(updated_category)
    end
  end

  @doc """
  商品数を増やす
  """
  def increment_product_count(category_id) do
    with {:ok, category} <- get(category_id) do
      update_product_count(category_id, category.product_count + 1)
    end
  end

  @doc """
  商品数を減らす
  """
  def decrement_product_count(category_id) do
    with {:ok, category} <- get(category_id),
         new_count when new_count >= 0 <- category.product_count - 1 do
      update_product_count(category_id, new_count)
    else
      _ -> {:error, :invalid_operation}
    end
  end

  @doc """
  すべてのプロジェクションをクリアする
  """
  def clear_all do
    # TODO: バッチ削除の実装
    case get_all() do
      {:ok, categories} ->
        Enum.each(categories, fn category ->
          delete(category.id)
        end)
        {:ok, length(categories)}
      
      error -> 
        error
    end
  end

  @doc """
  カテゴリーを作成する
  """
  def create(attrs) do
    category = struct(Category, attrs)
    save(category)
  end

  @doc """
  カテゴリーを更新する
  """
  def update(id, attrs) do
    with {:ok, category} <- get(id) do
      updated = struct(category, attrs)
      save(updated)
    end
  end

  @doc """
  すべて削除（delete_all）
  """
  def delete_all do
    clear_all()
  end

  # Private functions

  defp build_query_opts(filters) do
    opts = []
    
    # ページネーション
    opts = if Map.has_key?(filters, :limit), do: [{:limit, filters.limit} | opts], else: opts
    opts = if Map.has_key?(filters, :offset), do: [{:offset, filters.offset} | opts], else: opts
    
    opts
  end

  defp apply_sorting(categories, %{sort_by: field, sort_order: order}) do
    Enum.sort_by(categories, &Map.get(&1, field), order_to_fun(order))
  end
  defp apply_sorting(categories, _), do: categories

  defp order_to_fun(:asc), do: &<=/2
  defp order_to_fun(:desc), do: &>=/2
  defp order_to_fun(_), do: &<=/2

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
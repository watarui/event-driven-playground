defmodule CommandService.Infrastructure.Repositories.CategoryRepository do
  @moduledoc """
  カテゴリーエンティティのリポジトリ実装（Firestore版）
  """

  alias CommandService.Domain.Models.Category
  alias Shared.Infrastructure.Firestore.Repository

  @collection "categories"

  @doc """
  カテゴリーを保存する
  """
  def save(%Category{} = category) do
    data = %{
      id: category.id,
      name: category.name,
      description: category.description,
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
  def get_all(opts \\ []) do
    case Repository.list(@collection, opts) do
      {:ok, data_list} ->
        categories =
          Enum.map(data_list, fn data ->
            %Category{
              id: data["id"] || data[:id],
              name: data["name"] || data[:name],
              description: data["description"] || data[:description],
              created_at: parse_datetime(data["created_at"] || data[:created_at]),
              updated_at: parse_datetime(data["updated_at"] || data[:updated_at])
            }
          end)

        {:ok, categories}

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
  カテゴリー名で検索する
  """
  def find_by_name(name) do
    # TODO: Firestore のクエリ機能を使用して実装
    # 一時的に全件取得してフィルタリング
    case get_all() do
      {:ok, categories} ->
        case Enum.find(categories, fn cat -> cat.name == name end) do
          nil -> {:error, :not_found}
          category -> {:ok, category}
        end

      error ->
        error
    end
  end

  @doc """
  カテゴリーに子カテゴリーがあるかチェック
  """
  def has_children?(_category_id) do
    # 現在の実装では子カテゴリーの概念がないため、常にfalse
    {:ok, false}
  end

  @doc """
  カテゴリーに商品があるかチェック
  """
  def has_products?(category_id) do
    case CommandService.Infrastructure.Repositories.ProductRepository.find_by_category(
           category_id
         ) do
      {:ok, products} -> {:ok, not Enum.empty?(products)}
      error -> error
    end
  end

  # Private functions

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

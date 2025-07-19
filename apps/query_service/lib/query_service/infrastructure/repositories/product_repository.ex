defmodule QueryService.Infrastructure.Repositories.ProductRepository do
  @moduledoc """
  商品リポジトリの実装（Read Model）

  クエリサービス用の商品データアクセス層
  """

  import Ecto.Query
  alias QueryService.Repo

  # スキーマ定義
  defmodule ProductSchema do
    @moduledoc """
    商品のEctoスキーマ定義
    """
    use Ecto.Schema
    import Shared.SchemaHelpers

    query_schema()
    @primary_key {:id, :binary_id, autogenerate: false}

    schema "products" do
      field(:name, :string)
      field(:description, :string)
      field(:category_id, :binary_id)
      field(:category_name, :string)
      field(:price_amount, :decimal)
      field(:price_currency, :string)
      field(:stock_quantity, :integer)
      field(:active, :boolean, default: true)
      field(:metadata, :map, default: %{})

      timestamps()
    end
  end

  @doc """
  IDで商品を取得
  """
  def get(id) do
    case Repo.get(ProductSchema, id) do
      nil -> {:error, :not_found}
      product -> {:ok, to_domain_model(product)}
    end
  end

  @doc """
  商品一覧を取得
  """
  def get_all(filters \\ %{}) do
    query =
      ProductSchema
      |> maybe_filter_active(filters[:active])
      |> maybe_filter_category(filters[:category_id])
      |> maybe_sort(filters[:sort_by], filters[:sort_order])
      |> maybe_limit(filters[:limit])
      |> maybe_offset(filters[:offset])

    products = Repo.all(query)
    {:ok, Enum.map(products, &to_domain_model/1)}
  end

  @doc """
  商品を検索
  """
  def search(search_term, filters \\ %{}) do
    pattern = "%#{search_term}%"

    query =
      from(p in ProductSchema,
        where: ilike(p.name, ^pattern) or ilike(p.description, ^pattern),
        where: p.active == true
      )

    query =
      query
      |> maybe_filter_category(filters[:category_id])
      |> maybe_sort(filters[:sort_by], filters[:sort_order])
      |> maybe_limit(filters[:limit])
      |> maybe_offset(filters[:offset])

    products = Repo.all(query)
    {:ok, Enum.map(products, &to_domain_model/1)}
  end

  @doc """
  価格範囲で商品を取得
  """
  def get_by_price_range(filters) do
    query = from(p in ProductSchema, where: p.active == true)

    query =
      query
      |> maybe_filter_min_price(filters[:min_price])
      |> maybe_filter_max_price(filters[:max_price])
      |> maybe_filter_category(filters[:category_id])
      |> maybe_sort(filters[:sort_by], filters[:sort_order])
      |> maybe_limit(filters[:limit])
      |> maybe_offset(filters[:offset])

    products = Repo.all(query)
    {:ok, Enum.map(products, &to_domain_model/1)}
  end

  # Private functions

  defp to_domain_model(schema) do
    %QueryService.Domain.Models.Product{
      id: schema.id,
      name: schema.name,
      description: schema.description,
      price: schema.price_amount,
      currency: schema.price_currency,
      category_id: schema.category_id,
      category_name: schema.category_name,
      stock_quantity: schema.stock_quantity,
      active: schema.active,
      created_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  defp maybe_filter_active(query, nil), do: query

  defp maybe_filter_active(query, active) do
    from(p in query, where: p.active == ^active)
  end

  defp maybe_filter_category(query, nil), do: query

  defp maybe_filter_category(query, category_id) do
    from(p in query, where: p.category_id == ^category_id)
  end

  defp maybe_filter_min_price(query, nil), do: query

  defp maybe_filter_min_price(query, min_price) do
    from(p in query, where: p.price_amount >= ^min_price)
  end

  defp maybe_filter_max_price(query, nil), do: query

  defp maybe_filter_max_price(query, max_price) do
    from(p in query, where: p.price_amount <= ^max_price)
  end

  defp maybe_sort(query, nil, _), do: from(p in query, order_by: [asc: p.name])

  defp maybe_sort(query, "price", order) do
    order = order || :asc
    from(p in query, order_by: [{^order, p.price_amount}])
  end

  defp maybe_sort(query, field, order) do
    order = order || :asc
    from(p in query, order_by: [{^order, ^String.to_atom(field)}])
  end

  defp maybe_limit(query, nil), do: query
  defp maybe_limit(query, limit), do: from(p in query, limit: ^limit)

  defp maybe_offset(query, nil), do: query
  defp maybe_offset(query, offset), do: from(p in query, offset: ^offset)

  @doc """
  商品を作成
  """
  def create(attrs) do
    changeset =
      Ecto.Changeset.cast(%ProductSchema{}, attrs, [
        :id,
        :name,
        :description,
        :price_amount,
        :price_currency,
        :stock_quantity,
        :category_id,
        :category_name,
        :active,
        :metadata,
        :inserted_at,
        :updated_at
      ])

    case Repo.insert(changeset) do
      {:ok, product} -> {:ok, to_domain_model(product)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  商品を更新
  """
  def update(id, attrs) do
    with {:ok, product} <- Repo.get(ProductSchema, id) |> handle_get_result() do
      changeset =
        Ecto.Changeset.cast(product, attrs, [
          :name,
          :description,
          :price_amount,
          :price_currency,
          :stock_quantity,
          :category_id,
          :category_name,
          :active,
          :metadata,
          :updated_at
        ])

      case Repo.update(changeset) do
        {:ok, updated} -> {:ok, to_domain_model(updated)}
        {:error, changeset} -> {:error, changeset}
      end
    end
  end

  @doc """
  商品を削除
  """
  def delete(id) do
    with {:ok, product} <- Repo.get(ProductSchema, id) |> handle_get_result() do
      case Repo.delete(product) do
        {:ok, _} -> {:ok, nil}
        {:error, changeset} -> {:error, changeset}
      end
    end
  end

  @doc """
  すべての商品を削除
  """
  def delete_all do
    {count, _} = Repo.delete_all(ProductSchema)
    {:ok, count}
  rescue
    e -> {:error, e}
  end

  defp handle_get_result(nil), do: {:error, :not_found}
  defp handle_get_result(result), do: {:ok, result}
end

defmodule QueryService.Infrastructure.Repositories.CategoryRepository do
  @moduledoc """
  カテゴリリポジトリの実装（Read Model）

  クエリサービス用のカテゴリデータアクセス層
  """

  import Ecto.Query
  alias QueryService.Repo

  # スキーマ定義
  defmodule CategorySchema do
    @moduledoc """
    カテゴリのEctoスキーマ定義
    """
    use Ecto.Schema
    import Shared.SchemaHelpers

    query_schema()
    @primary_key {:id, :binary_id, autogenerate: false}

    schema "categories" do
      field(:name, :string)
      field(:description, :string)
      field(:parent_id, :binary_id)
      field(:active, :boolean, default: true)
      field(:product_count, :integer, default: 0)
      field(:metadata, :map, default: %{})

      timestamps()
    end
  end

  @doc """
  IDでカテゴリを取得
  """
  def get(id) do
    case Repo.get(CategorySchema, id) do
      nil -> {:error, :not_found}
      category -> {:ok, to_domain_model(category)}
    end
  end

  @doc """
  すべてのカテゴリを取得
  """
  def get_all(filters \\ %{}) do
    query =
      CategorySchema
      |> maybe_filter_active(filters[:active])
      |> maybe_filter_parent(filters[:parent_id])
      |> maybe_sort(filters[:sort_by], filters[:sort_order])
      |> maybe_limit(filters[:limit])
      |> maybe_offset(filters[:offset])

    categories = Repo.all(query)
    {:ok, Enum.map(categories, &to_domain_model/1)}
  end

  @doc """
  親カテゴリIDでカテゴリを取得
  """
  def get_by_parent(parent_id) do
    query =
      from(c in CategorySchema,
        where: c.parent_id == ^parent_id,
        where: c.active == true,
        order_by: [asc: c.name]
      )

    categories = Repo.all(query)
    {:ok, Enum.map(categories, &to_domain_model/1)}
  end

  @doc """
  カテゴリを検索
  """
  def search(keyword) do
    pattern = "%#{keyword}%"

    query =
      from(c in CategorySchema,
        where: ilike(c.name, ^pattern) or ilike(c.description, ^pattern),
        where: c.active == true,
        order_by: [asc: c.name]
      )

    categories = Repo.all(query)
    {:ok, Enum.map(categories, &to_domain_model/1)}
  end

  @doc """
  カテゴリを作成
  """
  def create(attrs) do
    changeset =
      Ecto.Changeset.cast(%CategorySchema{}, attrs, [
        :id,
        :name,
        :description,
        :parent_id,
        :active,
        :product_count,
        :metadata,
        :inserted_at,
        :updated_at
      ])

    case Repo.insert(changeset) do
      {:ok, category} -> {:ok, to_domain_model(category)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  カテゴリを更新
  """
  def update(id, attrs) do
    with {:ok, category} <- Repo.get(CategorySchema, id) |> handle_get_result() do
      changeset =
        Ecto.Changeset.cast(category, attrs, [
          :name,
          :description,
          :parent_id,
          :active,
          :product_count,
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
  カテゴリを削除
  """
  def delete(id) do
    with {:ok, category} <- Repo.get(CategorySchema, id) |> handle_get_result() do
      case Repo.delete(category) do
        {:ok, _} -> {:ok, nil}
        {:error, changeset} -> {:error, changeset}
      end
    end
  end

  @doc """
  すべてのカテゴリを削除
  """
  def delete_all do
    {count, _} = Repo.delete_all(CategorySchema)
    {:ok, count}
  rescue
    e -> {:error, e}
  end

  # Private functions

  defp to_domain_model(schema) do
    %QueryService.Domain.Models.Category{
      id: schema.id,
      name: schema.name,
      description: schema.description,
      parent_id: schema.parent_id,
      active: schema.active,
      product_count: schema.product_count,
      created_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  defp maybe_filter_active(query, nil), do: query

  defp maybe_filter_active(query, active) do
    from(c in query, where: c.active == ^active)
  end

  defp maybe_filter_parent(query, nil), do: query

  defp maybe_filter_parent(query, parent_id) do
    from(c in query, where: c.parent_id == ^parent_id)
  end

  defp maybe_sort(query, nil, _), do: from(c in query, order_by: [asc: c.name])

  defp maybe_sort(query, field, order) do
    order = order || :asc
    from(c in query, order_by: [{^order, ^String.to_atom(field)}])
  end

  defp maybe_limit(query, nil), do: query
  defp maybe_limit(query, limit), do: from(c in query, limit: ^limit)

  defp maybe_offset(query, nil), do: query
  defp maybe_offset(query, offset), do: from(c in query, offset: ^offset)

  defp handle_get_result(nil), do: {:error, :not_found}
  defp handle_get_result(result), do: {:ok, result}
end

defmodule CommandService.Infrastructure.Repositories.ProductRepository do
  @moduledoc """
  商品リポジトリの実装

  商品アグリゲートの永続化とイベントストアからの復元を行います。
  """

  import Ecto.Query

  alias CommandService.Repo
  alias CommandService.Domain.Aggregates.ProductAggregate
  alias Shared.Infrastructure.EventStore.EventStore

  @behaviour CommandService.Domain.Repositories.ProductRepository

  # スキーマ定義
  defmodule ProductSchema do
    @moduledoc """
    商品のEctoスキーマ定義
    """
    use Ecto.Schema
    import Shared.SchemaHelpers

    command_schema()
    @primary_key {:id, :binary_id, autogenerate: false}
    @foreign_key_type :binary_id

    schema "products" do
      field(:name, :string)
      field(:description, :string)
      field(:category_id, :binary_id)
      field(:price_amount, :decimal)
      field(:price_currency, :string)
      field(:stock_quantity, :integer)
      field(:active, :boolean, default: true)
      field(:version, :integer, default: 0)
      field(:metadata, :map, default: %{})

      timestamps()
    end
  end

  @impl true
  def get(id) do
    case Repo.get(ProductSchema, id) do
      nil ->
        {:error, :not_found}

      schema ->
        # イベントストアから履歴を取得して再構築
        case EventStore.get_events(id) do
          {:ok, events} ->
            aggregate = rebuild_aggregate(schema, events)
            {:ok, aggregate}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @impl true
  def save(%ProductAggregate{} = aggregate) do
    # 既存のレコードを取得
    existing_schema = Repo.get(ProductSchema, aggregate.id.value)
    changeset = build_changeset(aggregate, existing_schema)

    case Repo.insert_or_update(changeset) do
      {:ok, _schema} ->
        {:ok, aggregate}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @impl true
  def exists?(id) do
    query = from(p in ProductSchema, where: p.id == ^id)
    Repo.exists?(query)
  end

  @impl true
  def find_by_name(name) do
    query = from(p in ProductSchema, where: p.name == ^name)

    case Repo.one(query) do
      nil ->
        {:error, :not_found}

      schema ->
        get(schema.id)
    end
  end

  @impl true
  def update_stock(product_id, quantity) do
    query =
      from(p in ProductSchema,
        where: p.id == ^product_id,
        update: [set: [stock_quantity: ^quantity]]
      )

    case Repo.update_all(query, []) do
      {1, _} -> :ok
      {0, _} -> {:error, :not_found}
    end
  end

  @impl true
  def check_stock(product_id, required_quantity) do
    query =
      from(p in ProductSchema,
        where: p.id == ^product_id,
        select: p.stock_quantity
      )

    case Repo.one(query) do
      nil -> {:error, :not_found}
      quantity when quantity >= required_quantity -> {:ok, quantity}
      quantity -> {:error, {:insufficient_stock, quantity}}
    end
  end

  # Private functions

  defp rebuild_aggregate(schema, events) do
    # スキーマから基本情報を復元
    base_aggregate = %ProductAggregate{
      id: schema.id,
      name: schema.name,
      description: schema.description,
      category_id: schema.category_id,
      price: %{
        amount: schema.price_amount,
        currency: schema.price_currency
      },
      stock_quantity: schema.stock_quantity,
      active: schema.active,
      version: schema.version,
      deleted: false,
      created_at: schema.inserted_at,
      updated_at: schema.updated_at,
      uncommitted_events: []
    }

    # イベントを適用して最新状態を復元
    Enum.reduce(events, base_aggregate, fn event, agg ->
      ProductAggregate.apply_event(agg, event)
    end)
  end

  defp build_changeset(%ProductAggregate{} = aggregate, existing_schema) do
    data = %{
      id: aggregate.id.value,
      name: aggregate.name.value,
      description: aggregate.description,
      category_id: aggregate.category_id.value,
      price_amount: aggregate.price.amount,
      price_currency: aggregate.price.currency,
      stock_quantity: aggregate.stock_quantity,
      active: aggregate.active,
      version: aggregate.version,
      metadata: Map.get(aggregate, :metadata, %{})
    }

    # 既存のスキーマがある場合はそれを使用、ない場合は新規作成
    schema = existing_schema || %ProductSchema{}

    schema
    |> Ecto.Changeset.cast(data, [
      :id,
      :name,
      :description,
      :category_id,
      :price_amount,
      :price_currency,
      :stock_quantity,
      :active,
      :version,
      :metadata
    ])
    |> Ecto.Changeset.validate_required([
      :id,
      :name,
      :category_id,
      :price_amount,
      :price_currency,
      :stock_quantity
    ])
  end
end

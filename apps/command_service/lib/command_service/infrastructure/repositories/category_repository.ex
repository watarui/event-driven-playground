defmodule CommandService.Infrastructure.Repositories.CategoryRepository do
  @moduledoc """
  カテゴリリポジトリの実装

  カテゴリアグリゲートの永続化とイベントストアからの復元を行います。
  """

  import Ecto.Query

  alias CommandService.Repo
  alias CommandService.Domain.Aggregates.CategoryAggregate
  alias Shared.Infrastructure.EventStore.EventStore

  @behaviour CommandService.Domain.Repositories.CategoryRepository

  # スキーマ定義
  defmodule CategorySchema do
    @moduledoc """
    カテゴリのEctoスキーマ定義
    """
    use Ecto.Schema
    import Shared.SchemaHelpers

    command_schema()
    @primary_key {:id, :binary_id, autogenerate: false}

    schema "categories" do
      field(:name, :string)
      field(:description, :string)
      field(:parent_id, :binary_id)
      field(:active, :boolean, default: true)
      field(:version, :integer, default: 0)
      field(:metadata, :map, default: %{})

      timestamps()
    end
  end

  @impl true
  def get(id) do
    case Repo.get(CategorySchema, id) do
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
  def save(%CategoryAggregate{} = aggregate) do
    require Logger
    Logger.debug("CategoryRepository.save - aggregate: #{inspect(aggregate)}")
    Logger.debug("CategoryRepository.save - aggregate.id: #{inspect(aggregate.id)}")
    Logger.debug("CategoryRepository.save - aggregate.name: #{inspect(aggregate.name)}")

    # 既存のレコードを取得
    id_value =
      case aggregate.id do
        %{value: value} -> value
        value when is_binary(value) -> value
        _ -> nil
      end

    existing_schema = Repo.get(CategorySchema, id_value)
    changeset = build_changeset(aggregate, existing_schema)

    case Repo.insert_or_update(changeset) do
      {:ok, _schema} ->
        {:ok, aggregate}

      {:error, changeset} ->
        Logger.error("CategoryRepository.save - changeset error: #{inspect(changeset)}")
        {:error, changeset}
    end
  end

  @impl true
  def exists?(id) do
    query = from(c in CategorySchema, where: c.id == ^id)
    Repo.exists?(query)
  end

  @impl true
  def find_by_name(name) do
    query = from(c in CategorySchema, where: c.name == ^name)

    case Repo.one(query) do
      nil ->
        {:error, :not_found}

      schema ->
        get(schema.id)
    end
  end

  @doc """
  子カテゴリが存在するかチェック
  """
  def has_children?(category_id) do
    query = from(c in CategorySchema, where: c.parent_id == ^category_id)
    Repo.exists?(query)
  end

  @doc """
  カテゴリに商品が存在するかチェック
  """
  def has_products?(category_id) do
    # ProductRepository が実装されたら使用
    # query = from p in ProductSchema, where: p.category_id == ^category_id
    # Repo.exists?(query)
    false
  end

  # Private functions

  defp rebuild_aggregate(schema, events) do
    # スキーマから基本情報を復元
    base_aggregate = %CategoryAggregate{
      id: schema.id,
      name: schema.name,
      description: schema.description,
      parent_id: schema.parent_id,
      active: schema.active,
      version: schema.version,
      deleted: false,
      created_at: schema.inserted_at,
      updated_at: schema.updated_at,
      uncommitted_events: []
    }

    # イベントを適用して最新状態を復元
    Enum.reduce(events, base_aggregate, fn event, agg ->
      CategoryAggregate.apply_event(agg, event)
    end)
  end

  defp build_changeset(%CategoryAggregate{} = aggregate, existing_schema) do
    # idフィールドが値オブジェクトかどうかチェック
    id_value =
      case aggregate.id do
        %{value: value} -> value
        value when is_binary(value) -> value
        _ -> nil
      end

    # nameフィールドが値オブジェクトかどうかチェック
    name_value =
      case aggregate.name do
        %{value: value} -> value
        value when is_binary(value) -> value
        nil -> nil
        _ -> nil
      end

    # parent_idフィールドが値オブジェクトかどうかチェック
    parent_id_value =
      case aggregate.parent_id do
        %{value: value} -> value
        value when is_binary(value) -> value
        nil -> nil
        _ -> nil
      end

    data = %{
      id: id_value,
      name: name_value,
      description: aggregate.description,
      parent_id: parent_id_value,
      active: aggregate.active,
      version: aggregate.version,
      metadata: Map.get(aggregate, :metadata, %{})
    }

    # 既存のスキーマがある場合はそれを使用、ない場合は新規作成
    schema = existing_schema || %CategorySchema{}

    schema
    |> Ecto.Changeset.cast(data, [
      :id,
      :name,
      :description,
      :parent_id,
      :active,
      :version,
      :metadata
    ])
    |> Ecto.Changeset.validate_required([:id, :name])
  end
end

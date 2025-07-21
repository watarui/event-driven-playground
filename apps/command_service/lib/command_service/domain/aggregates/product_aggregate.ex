defmodule CommandService.Domain.Aggregates.ProductAggregate do
  @moduledoc """
  商品アグリゲート

  商品の作成、更新、価格変更、削除に関するビジネスロジックを管理します
  """

  use Shared.Domain.Aggregate.Base

  alias Shared.Domain.ValueObjects.{EntityId, Money, ProductName}

  alias Shared.Domain.Events.ProductEvents.{
    ProductCreated,
    ProductDeleted,
    ProductPriceChanged,
    ProductUpdated
  }

  alias CommandService.Application.Commands.ProductCommands

  @enforce_keys [:id]
  defstruct [
    :id,
    :name,
    :description,
    :price,
    :category_id,
    :stock_quantity,
    :active,
    :version,
    :deleted,
    :created_at,
    :updated_at,
    uncommitted_events: []
  ]

  @type t :: %__MODULE__{
          id: EntityId.t(),
          name: ProductName.t() | nil,
          description: String.t() | nil,
          price: Money.t() | nil,
          category_id: EntityId.t() | nil,
          stock_quantity: integer(),
          active: boolean(),
          version: integer(),
          deleted: boolean(),
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          uncommitted_events: list()
        }

  @impl true
  def new do
    %__MODULE__{
      id: EntityId.generate(),
      stock_quantity: 0,
      active: true,
      version: 0,
      deleted: false,
      uncommitted_events: []
    }
  end

  @doc """
  商品を作成する
  """
  @spec create(String.t(), number(), String.t(), Keyword.t()) :: {:ok, t()} | {:error, String.t()}
  def create(name, price, category_id, opts \\ []) do
    with {:ok, product_name} <- ProductName.new(name),
         {:ok, money} <- Money.new(price),
         {:ok, cat_id} <- EntityId.from_string(category_id) do
      aggregate = new()

      event =
        ProductCreated.new(%{
          id: aggregate.id,
          name: product_name,
          price: money,
          category_id: cat_id,
          stock_quantity: Keyword.get(opts, :stock_quantity, 0),
          description: Keyword.get(opts, :description),
          created_at: DateTime.utc_now()
        })

      {:ok, apply_and_record_event(aggregate, event)}
    end
  end

  @doc """
  商品情報を更新する
  """
  @spec update(t(), map()) :: {:ok, t()} | {:error, String.t()}
  def update(%__MODULE__{deleted: true}, _params) do
    {:error, "Cannot update deleted product"}
  end

  def update(%__MODULE__{} = aggregate, params) do
    with {:ok, updates} <- validate_updates(aggregate, params) do
      if map_size(updates) == 0 do
        {:error, "No changes to update"}
      else
        event =
          ProductUpdated.new(
            Map.merge(updates, %{
              id: aggregate.id,
              updated_at: DateTime.utc_now()
            })
          )

        {:ok, apply_and_record_event(aggregate, event)}
      end
    end
  end

  @doc """
  商品価格を変更する（価格変更専用のイベント）
  """
  @spec change_price(t(), number()) :: {:ok, t()} | {:error, String.t()}
  def change_price(%__MODULE__{deleted: true}, _new_price) do
    {:error, "Cannot change price of deleted product"}
  end

  def change_price(%__MODULE__{price: nil}, _new_price) do
    {:error, "Product price not initialized"}
  end

  def change_price(%__MODULE__{} = aggregate, new_price) do
    with {:ok, new_money} <- Money.new(new_price) do
      case Money.compare(aggregate.price, new_money) do
        :eq ->
          {:error, "Price is the same"}

        _ ->
          event =
            ProductPriceChanged.new(%{
              id: aggregate.id,
              old_price: aggregate.price,
              new_price: new_money,
              changed_at: DateTime.utc_now()
            })

          {:ok, apply_and_record_event(aggregate, event)}
      end
    end
  end

  @doc """
  商品を削除する
  """
  @spec delete(t()) :: {:ok, t()} | {:error, String.t()}
  def delete(%__MODULE__{deleted: true}) do
    {:error, "Product already deleted"}
  end

  def delete(%__MODULE__{} = aggregate) do
    event =
      ProductDeleted.new(%{
        id: aggregate.id,
        deleted_at: DateTime.utc_now()
      })

    {:ok, apply_and_record_event(aggregate, event)}
  end

  # Private functions

  defp validate_updates(aggregate, params) do
    with {:ok, name_update} <- validate_name_update(aggregate, params[:name]),
         {:ok, price_update} <- validate_price_update(aggregate, params[:price]),
         {:ok, category_update} <- validate_category_update(aggregate, params[:category_id]) do
      updates =
        %{}
        |> maybe_add_update(:name, name_update)
        |> maybe_add_update(:price, price_update)
        |> maybe_add_update(:category_id, category_update)

      {:ok, updates}
    end
  end

  defp validate_name_update(_aggregate, nil), do: {:ok, nil}

  defp validate_name_update(aggregate, name) do
    case ProductName.new(name) do
      {:ok, new_name} ->
        if aggregate.name && aggregate.name.value == new_name.value do
          {:ok, nil}
        else
          {:ok, new_name}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_price_update(_aggregate, nil), do: {:ok, nil}

  defp validate_price_update(aggregate, price) do
    case Money.new(price) do
      {:ok, new_price} ->
        if aggregate.price && Money.compare(aggregate.price, new_price) == :eq do
          {:ok, nil}
        else
          {:ok, new_price}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_category_update(_aggregate, nil), do: {:ok, nil}

  defp validate_category_update(aggregate, category_id) do
    case EntityId.from_string(category_id) do
      {:ok, new_cat_id} ->
        if aggregate.category_id && aggregate.category_id.value == new_cat_id.value do
          {:ok, nil}
        else
          {:ok, new_cat_id}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_add_update(updates, _key, nil), do: updates
  defp maybe_add_update(updates, key, value), do: Map.put(updates, key, value)

  @impl true
  def apply_event(aggregate, %ProductCreated{} = event) do
    %{
      aggregate
      | id: event.id,
        name: event.name,
        description: Map.get(event, :description),
        price: event.price,
        category_id: event.category_id,
        stock_quantity: Map.get(event, :stock_quantity, 0),
        created_at: event.created_at,
        updated_at: event.created_at
    }
  end

  def apply_event(aggregate, %ProductUpdated{} = event) do
    aggregate
    |> maybe_update(:name, event.name)
    |> maybe_update(:price, event.price)
    |> maybe_update(:category_id, event.category_id)
    |> Map.put(:updated_at, event.updated_at)
  end

  def apply_event(aggregate, %ProductPriceChanged{} = event) do
    %{aggregate | price: event.new_price, updated_at: event.changed_at}
  end

  def apply_event(aggregate, %ProductDeleted{} = event) do
    %{aggregate | deleted: true, updated_at: event.deleted_at}
  end

  defp maybe_update(aggregate, field, value) do
    if value do
      Map.put(aggregate, field, value)
    else
      aggregate
    end
  end

  @doc """
  コマンドを実行する
  """
  def execute(aggregate, %ProductCommands.CreateProduct{} = command) do
    if aggregate.created_at do
      {:error, "Product already created"}
    else
      with {:ok, product_name} <- ProductName.new(command.name),
           {:ok, money} <- Money.new(command.price),
           {:ok, cat_id} <- EntityId.from_string(command.category_id) do
        event =
          ProductCreated.new(%{
            id: aggregate.id,
            name: product_name,
            description: command.description,
            price: money,
            category_id: cat_id,
            stock_quantity: command.stock_quantity || 0,
            created_at: DateTime.utc_now()
          })

        updated_aggregate = apply_and_record_event(aggregate, event)
        {:ok, updated_aggregate, [event]}
      end
    end
  end

  def execute(aggregate, %ProductCommands.UpdateProduct{} = command) do
    if aggregate.deleted do
      {:error, "Cannot update deleted product"}
    else
      params = %{
        name: command.name,
        price: command.price,
        category_id: command.category_id,
        description: Map.get(command.metadata || %{}, :description)
      }

      with {:ok, updates} <- validate_updates(aggregate, params) do
        if map_size(updates) == 0 do
          {:error, "No changes to update"}
        else
          event =
            ProductUpdated.new(
              Map.merge(updates, %{
                id: aggregate.id,
                updated_at: DateTime.utc_now()
              })
            )

          updated_aggregate = apply_and_record_event(aggregate, event)
          {:ok, updated_aggregate, [event]}
        end
      end
    end
  end

  def execute(aggregate, %ProductCommands.ChangeProductPrice{} = command) do
    if aggregate.deleted do
      {:error, "Cannot change price of deleted product"}
    else
      with {:ok, new_money} <- Money.new(command.new_price) do
        case Money.compare(aggregate.price, new_money) do
          :eq ->
            {:error, "Price is the same"}

          _ ->
            event =
              ProductPriceChanged.new(%{
                id: aggregate.id,
                old_price: aggregate.price,
                new_price: new_money,
                changed_at: DateTime.utc_now()
              })

            updated_aggregate = apply_and_record_event(aggregate, event)
            {:ok, updated_aggregate, [event]}
        end
      end
    end
  end

  def execute(aggregate, %ProductCommands.DeleteProduct{}) do
    if aggregate.deleted do
      {:error, "Product already deleted"}
    else
      event =
        ProductDeleted.new(%{
          id: aggregate.id,
          deleted_at: DateTime.utc_now()
        })

      updated_aggregate = apply_and_record_event(aggregate, event)
      {:ok, updated_aggregate, [event]}
    end
  end

  def execute(aggregate, %ProductCommands.UpdateStock{} = command) do
    if aggregate.deleted do
      {:error, "Cannot update stock of deleted product"}
    else
      event =
        ProductUpdated.new(%{
          id: aggregate.id,
          stock_quantity: command.quantity,
          updated_at: DateTime.utc_now()
        })

      updated_aggregate = apply_and_record_event(aggregate, event)
      {:ok, updated_aggregate, [event]}
    end
  end

  def execute(aggregate, %ProductCommands.ReserveStock{} = command) do
    if aggregate.deleted do
      {:error, "Cannot reserve stock of deleted product"}
    else
      new_quantity = aggregate.stock_quantity - command.quantity

      if new_quantity < 0 do
        {:error, "Insufficient stock"}
      else
        event =
          ProductUpdated.new(%{
            id: aggregate.id,
            stock_quantity: new_quantity,
            updated_at: DateTime.utc_now()
          })

        updated_aggregate = apply_and_record_event(aggregate, event)
        {:ok, updated_aggregate, [event]}
      end
    end
  end

  def execute(aggregate, %ProductCommands.ReleaseStock{} = command) do
    if aggregate.deleted do
      {:error, "Cannot release stock of deleted product"}
    else
      new_quantity = aggregate.stock_quantity + command.quantity

      event =
        ProductUpdated.new(%{
          id: aggregate.id,
          stock_quantity: new_quantity,
          updated_at: DateTime.utc_now()
        })

      updated_aggregate = apply_and_record_event(aggregate, event)
      {:ok, updated_aggregate, [event]}
    end
  end
end

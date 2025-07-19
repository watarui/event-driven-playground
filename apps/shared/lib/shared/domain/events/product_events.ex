defmodule Shared.Domain.Events.ProductEvents do
  @moduledoc """
  商品に関連するドメインイベント
  """

  alias Shared.Domain.ValueObjects.{EntityId, Money, ProductName}

  defmodule ProductCreated do
    @moduledoc """
    商品作成イベント
    """
    use Shared.Domain.Events.BaseEvent

    @enforce_keys [:id, :name, :price, :category_id, :created_at]
    defstruct [:id, :name, :description, :price, :stock_quantity, :category_id, :created_at]

    @type t :: %__MODULE__{
            id: EntityId.t(),
            name: ProductName.t(),
            description: String.t() | nil,
            price: Money.t(),
            stock_quantity: integer(),
            category_id: EntityId.t(),
            created_at: DateTime.t()
          }

    @impl true
    def new(params) do
      %__MODULE__{
        id: params.id,
        name: params.name,
        description: params[:description],
        price: params.price,
        stock_quantity: params[:stock_quantity] || 0,
        category_id: params.category_id,
        created_at: params[:created_at] || DateTime.utc_now()
      }
    end

    @impl true
    def event_type, do: "product.created"

    @impl true
    def aggregate_type, do: "product"
  end

  defmodule ProductUpdated do
    @moduledoc """
    商品更新イベント
    """
    use Shared.Domain.Events.BaseEvent

    @enforce_keys [:id, :updated_at]
    defstruct [:id, :name, :description, :price, :category_id, :updated_at]

    @type t :: %__MODULE__{
            id: EntityId.t(),
            name: ProductName.t() | nil,
            description: String.t() | nil,
            price: Money.t() | nil,
            category_id: EntityId.t() | nil,
            updated_at: DateTime.t()
          }

    @impl true
    def new(params) do
      %__MODULE__{
        id: params.id,
        name: params[:name],
        description: params[:description],
        price: params[:price],
        category_id: params[:category_id],
        updated_at: params[:updated_at] || DateTime.utc_now()
      }
    end

    @impl true
    def event_type, do: "product.updated"

    @impl true
    def aggregate_type, do: "product"
  end

  defmodule ProductPriceChanged do
    @moduledoc """
    商品価格変更イベント
    """
    use Shared.Domain.Events.BaseEvent

    @enforce_keys [:id, :old_price, :new_price, :changed_at]
    defstruct [:id, :old_price, :new_price, :changed_at]

    @type t :: %__MODULE__{
            id: EntityId.t(),
            old_price: Money.t(),
            new_price: Money.t(),
            changed_at: DateTime.t()
          }

    @impl true
    def new(params) do
      %__MODULE__{
        id: params.id,
        old_price: params.old_price,
        new_price: params.new_price,
        changed_at: params[:changed_at] || DateTime.utc_now()
      }
    end

    @impl true
    def event_type, do: "product.price_changed"

    @impl true
    def aggregate_type, do: "product"
  end

  defmodule ProductDeleted do
    @moduledoc """
    商品削除イベント
    """
    use Shared.Domain.Events.BaseEvent

    @enforce_keys [:id, :deleted_at]
    defstruct [:id, :deleted_at]

    @type t :: %__MODULE__{
            id: EntityId.t(),
            deleted_at: DateTime.t()
          }

    @impl true
    def new(params) do
      %__MODULE__{
        id: params.id,
        deleted_at: params[:deleted_at] || DateTime.utc_now()
      }
    end

    @impl true
    def event_type, do: "product.deleted"

    @impl true
    def aggregate_type, do: "product"
  end
end

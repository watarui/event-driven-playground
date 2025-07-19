defmodule Shared.Domain.Events.OrderEvents do
  @moduledoc """
  注文に関連するドメインイベント（SAGA パターン用）
  """

  alias Shared.Domain.ValueObjects.{EntityId, Money}

  defmodule OrderCreated do
    @moduledoc """
    注文作成イベント（SAGA 開始）
    """
    use Shared.Domain.Events.BaseEvent

    @enforce_keys [:id, :user_id, :items, :total_amount, :saga_id, :created_at]
    defstruct [:id, :user_id, :items, :total_amount, :saga_id, :created_at, :shipping_address]

    @type t :: %__MODULE__{
            id: EntityId.t(),
            user_id: EntityId.t(),
            items: list(map()),
            total_amount: Money.t(),
            saga_id: EntityId.t(),
            created_at: DateTime.t(),
            shipping_address: map() | nil
          }

    @impl true
    def new(params) do
      %__MODULE__{
        id: params.id,
        user_id: params.user_id,
        items: params.items,
        total_amount: params.total_amount,
        saga_id: params.saga_id,
        created_at: params[:created_at] || DateTime.utc_now(),
        shipping_address: params[:shipping_address]
      }
    end

    @impl true
    def event_type, do: "order.created"

    @impl true
    def aggregate_type, do: "order"
  end

  defmodule OrderItemReserved do
    @moduledoc """
    注文商品の在庫予約イベント
    """
    use Shared.Domain.Events.BaseEvent

    @enforce_keys [:order_id, :product_id, :quantity, :reserved_at]
    defstruct [:order_id, :product_id, :quantity, :reserved_at]

    @type t :: %__MODULE__{
            order_id: EntityId.t(),
            product_id: EntityId.t(),
            quantity: integer(),
            reserved_at: DateTime.t()
          }

    @impl true
    def new(params) do
      %__MODULE__{
        order_id: params.order_id,
        product_id: params.product_id,
        quantity: params.quantity,
        reserved_at: params[:reserved_at] || DateTime.utc_now()
      }
    end

    @impl true
    def event_type, do: "order.item_reserved"

    @impl true
    def aggregate_type, do: "order"
  end

  defmodule OrderPaymentProcessed do
    @moduledoc """
    注文支払い処理イベント
    """
    use Shared.Domain.Events.BaseEvent

    @enforce_keys [:order_id, :amount, :payment_id, :processed_at]
    defstruct [:order_id, :amount, :payment_id, :processed_at]

    @type t :: %__MODULE__{
            order_id: EntityId.t(),
            amount: Money.t(),
            payment_id: String.t(),
            processed_at: DateTime.t()
          }

    @impl true
    def new(params) do
      %__MODULE__{
        order_id: params.order_id,
        amount: params.amount,
        payment_id: params.payment_id,
        processed_at: params[:processed_at] || DateTime.utc_now()
      }
    end

    @impl true
    def event_type, do: "order.payment_processed"

    @impl true
    def aggregate_type, do: "order"
  end

  defmodule OrderConfirmed do
    @moduledoc """
    注文確定イベント
    """
    use Shared.Domain.Events.BaseEvent

    @enforce_keys [:id, :confirmed_at]
    defstruct [:id, :confirmed_at]

    @type t :: %__MODULE__{
            id: EntityId.t(),
            confirmed_at: DateTime.t()
          }

    @impl true
    def new(params) do
      %__MODULE__{
        id: params.id,
        confirmed_at: params[:confirmed_at] || DateTime.utc_now()
      }
    end

    @impl true
    def event_type, do: "order.confirmed"

    @impl true
    def aggregate_type, do: "order"
  end

  defmodule OrderCancelled do
    @moduledoc """
    注文キャンセルイベント
    """
    use Shared.Domain.Events.BaseEvent

    @enforce_keys [:id, :reason, :cancelled_at]
    defstruct [:id, :reason, :cancelled_at]

    @type t :: %__MODULE__{
            id: EntityId.t(),
            reason: String.t(),
            cancelled_at: DateTime.t()
          }

    @impl true
    def new(params) do
      %__MODULE__{
        id: params.id,
        reason: params.reason,
        cancelled_at: params[:cancelled_at] || DateTime.utc_now()
      }
    end

    @impl true
    def event_type, do: "order.cancelled"

    @impl true
    def aggregate_type, do: "order"
  end

  defmodule OrderCompensationStarted do
    @moduledoc """
    注文補償処理開始イベント
    """
    use Shared.Domain.Events.BaseEvent

    @enforce_keys [:order_id, :saga_id, :reason, :started_at]
    defstruct [:order_id, :saga_id, :reason, :started_at]

    @type t :: %__MODULE__{
            order_id: EntityId.t(),
            saga_id: EntityId.t(),
            reason: String.t(),
            started_at: DateTime.t()
          }

    @impl true
    def new(params) do
      %__MODULE__{
        order_id: params.order_id,
        saga_id: params.saga_id,
        reason: params.reason,
        started_at: params[:started_at] || DateTime.utc_now()
      }
    end

    @impl true
    def event_type, do: "order.compensation_started"

    @impl true
    def aggregate_type, do: "order"
  end
end

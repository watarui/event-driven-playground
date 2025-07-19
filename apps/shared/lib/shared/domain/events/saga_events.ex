defmodule Shared.Domain.Events.SagaEvents do
  @moduledoc """
  SAGA処理用の追加イベント定義
  """

  defmodule InventoryReserved do
    @moduledoc """
    在庫予約成功イベント
    """
    defstruct [:saga_id, :order_id, :items, :event_type, :occurred_at]

    @type t :: %__MODULE__{
            saga_id: String.t(),
            order_id: String.t(),
            items: list(map()),
            event_type: String.t(),
            occurred_at: DateTime.t()
          }
  end

  defmodule InventoryReservationFailed do
    @moduledoc """
    在庫予約失敗イベント
    """
    defstruct [:saga_id, :order_id, :reason, :event_type, :occurred_at]

    @type t :: %__MODULE__{
            saga_id: String.t(),
            order_id: String.t(),
            reason: String.t(),
            event_type: String.t(),
            occurred_at: DateTime.t()
          }
  end

  defmodule PaymentProcessed do
    @moduledoc """
    支払い処理成功イベント
    """
    defstruct [:saga_id, :order_id, :amount, :transaction_id, :event_type, :occurred_at]

    @type t :: %__MODULE__{
            saga_id: String.t(),
            order_id: String.t(),
            amount: Decimal.t() | float() | integer(),
            transaction_id: String.t(),
            event_type: String.t(),
            occurred_at: DateTime.t()
          }
  end

  defmodule PaymentFailed do
    @moduledoc """
    支払い処理失敗イベント
    """
    defstruct [:saga_id, :order_id, :reason, :event_type, :occurred_at]

    @type t :: %__MODULE__{
            saga_id: String.t(),
            order_id: String.t(),
            reason: String.t(),
            event_type: String.t(),
            occurred_at: DateTime.t()
          }
  end

  defmodule ShippingArranged do
    @moduledoc """
    配送手配成功イベント
    """
    defstruct [:saga_id, :order_id, :shipping_id, :tracking_id, :event_type, :occurred_at]

    @type t :: %__MODULE__{
            saga_id: String.t(),
            order_id: String.t(),
            shipping_id: String.t(),
            tracking_id: String.t() | nil,
            event_type: String.t(),
            occurred_at: DateTime.t()
          }
  end

  defmodule ShippingArrangementFailed do
    @moduledoc """
    配送手配失敗イベント
    """
    defstruct [:saga_id, :order_id, :reason, :event_type, :occurred_at]

    @type t :: %__MODULE__{
            saga_id: String.t(),
            order_id: String.t(),
            reason: String.t(),
            event_type: String.t(),
            occurred_at: DateTime.t()
          }
  end

  defmodule InventoryReleased do
    @moduledoc """
    在庫解放イベント（補償）
    """
    defstruct [:saga_id, :order_id, :items, :event_type, :occurred_at]

    @type t :: %__MODULE__{
            saga_id: String.t(),
            order_id: String.t(),
            items: list(map()),
            event_type: String.t(),
            occurred_at: DateTime.t()
          }
  end

  defmodule PaymentRefunded do
    @moduledoc """
    返金処理イベント（補償）
    """
    defstruct [:saga_id, :order_id, :amount, :event_type, :occurred_at]

    @type t :: %__MODULE__{
            saga_id: String.t(),
            order_id: String.t(),
            amount: Decimal.t() | float() | integer(),
            event_type: String.t(),
            occurred_at: DateTime.t()
          }
  end

  defmodule ShippingCancelled do
    @moduledoc """
    配送キャンセルイベント（補償）
    """
    defstruct [:saga_id, :order_id, :event_type, :occurred_at]

    @type t :: %__MODULE__{
            saga_id: String.t(),
            order_id: String.t(),
            event_type: String.t(),
            occurred_at: DateTime.t()
          }
  end

  defmodule OrderCancelled do
    @moduledoc """
    注文キャンセルイベント（補償）
    """
    defstruct [:saga_id, :order_id, :reason, :event_type, :occurred_at]

    @type t :: %__MODULE__{
            saga_id: String.t(),
            order_id: String.t(),
            reason: String.t(),
            event_type: String.t(),
            occurred_at: DateTime.t()
          }
  end

  defmodule OrderConfirmed do
    @moduledoc """
    注文確定イベント
    """
    defstruct [:saga_id, :order_id, :event_type, :occurred_at]

    @type t :: %__MODULE__{
            saga_id: String.t(),
            order_id: String.t(),
            event_type: String.t(),
            occurred_at: DateTime.t()
          }
  end
end

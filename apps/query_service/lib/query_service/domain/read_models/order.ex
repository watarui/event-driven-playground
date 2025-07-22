defmodule QueryService.Domain.ReadModels.Order do
  @moduledoc """
  注文の読み取りモデル
  """

  @enforce_keys [:id, :customer_id, :status, :total_amount, :currency, :created_at, :updated_at]
  defstruct [
    :id,
    :customer_id,
    :status,
    :items,
    :total_amount,
    :currency,
    :shipping_address,
    :created_at,
    :updated_at,
    :confirmed_at,
    :shipped_at,
    :delivered_at,
    :cancelled_at
  ]

  @type status :: :pending | :confirmed | :shipped | :delivered | :cancelled

  @type t :: %__MODULE__{
          id: String.t(),
          customer_id: String.t(),
          status: status(),
          items: [Item.t()],
          total_amount: Decimal.t(),
          currency: String.t(),
          shipping_address: map() | nil,
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          confirmed_at: DateTime.t() | nil,
          shipped_at: DateTime.t() | nil,
          delivered_at: DateTime.t() | nil,
          cancelled_at: DateTime.t() | nil
        }

  defmodule Item do
    @moduledoc """
    注文アイテムの構造体
    """

    @enforce_keys [:product_id, :product_name, :quantity, :unit_price, :subtotal]
    defstruct [
      :product_id,
      :product_name,
      :quantity,
      :unit_price,
      :subtotal
    ]

    @type t :: %__MODULE__{
            product_id: String.t(),
            product_name: String.t(),
            quantity: integer(),
            unit_price: Decimal.t(),
            subtotal: Decimal.t()
          }
  end

  @doc """
  注文のサマリーを生成する
  """
  def summary(%__MODULE__{} = order) do
    %{
      id: order.id,
      customer_id: order.customer_id,
      status: order.status,
      item_count: length(order.items || []),
      total_amount: Decimal.to_string(order.total_amount),
      currency: order.currency,
      created_at: DateTime.to_iso8601(order.created_at)
    }
  end

  @doc """
  ステータスが有効かチェックする
  """
  def valid_status?(:pending), do: true
  def valid_status?(:confirmed), do: true
  def valid_status?(:shipped), do: true
  def valid_status?(:delivered), do: true
  def valid_status?(:cancelled), do: true
  def valid_status?(_), do: false

  @doc """
  注文が完了しているかチェックする
  """
  def completed?(%__MODULE__{status: :delivered}), do: true
  def completed?(%__MODULE__{status: :cancelled}), do: true
  def completed?(_), do: false

  @doc """
  注文がアクティブかチェックする
  """
  def active?(%__MODULE__{} = order), do: !completed?(order)

  defimpl Jason.Encoder do
    def encode(order, opts) do
      Jason.Encode.map(
        %{
          id: order.id,
          customer_id: order.customer_id,
          status: order.status,
          items: Enum.map(order.items || [], &encode_item/1),
          total_amount: Decimal.to_string(order.total_amount),
          currency: order.currency,
          shipping_address: order.shipping_address,
          created_at: DateTime.to_iso8601(order.created_at),
          updated_at: DateTime.to_iso8601(order.updated_at),
          confirmed_at: order.confirmed_at && DateTime.to_iso8601(order.confirmed_at),
          shipped_at: order.shipped_at && DateTime.to_iso8601(order.shipped_at),
          delivered_at: order.delivered_at && DateTime.to_iso8601(order.delivered_at),
          cancelled_at: order.cancelled_at && DateTime.to_iso8601(order.cancelled_at)
        },
        opts
      )
    end

    defp encode_item(item) do
      %{
        product_id: item.product_id,
        product_name: item.product_name,
        quantity: item.quantity,
        unit_price: Decimal.to_string(item.unit_price),
        subtotal: Decimal.to_string(item.subtotal)
      }
    end
  end
end

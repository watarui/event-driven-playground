defmodule CommandService.Domain.Models.Order do
  @moduledoc """
  注文ドメインモデル
  """

  defstruct [
    :id,
    :customer_id,
    :items,
    :total_amount,
    :currency,
    :status,
    :created_at,
    :updated_at
  ]

  defmodule Item do
    @moduledoc """
    注文アイテム
    """
    defstruct [
      :product_id,
      :quantity,
      :unit_price
    ]
  end

  @type status :: :pending | :confirmed | :cancelled

  @type t :: %__MODULE__{
          id: String.t(),
          customer_id: String.t(),
          items: [item_t()],
          total_amount: Decimal.t(),
          currency: String.t(),
          status: status(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @type item_t :: %Item{
          product_id: String.t(),
          quantity: non_neg_integer(),
          unit_price: Decimal.t()
        }

  @doc """
  新しい注文を作成
  """
  def new(customer_id, items) do
    %__MODULE__{
      id: UUID.uuid4(),
      customer_id: customer_id,
      items: items,
      total_amount: calculate_total(items),
      currency: "JPY",
      status: :pending,
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  @doc """
  注文を確定する
  """
  def confirm(%__MODULE__{status: :pending} = order) do
    %{order | status: :confirmed, updated_at: DateTime.utc_now()}
  end

  def confirm(_order), do: {:error, :invalid_status}

  @doc """
  注文をキャンセルする
  """
  def cancel(%__MODULE__{status: status} = order) when status in [:pending, :confirmed] do
    %{order | status: :cancelled, updated_at: DateTime.utc_now()}
  end

  def cancel(_order), do: {:error, :invalid_status}

  @doc """
  合計金額を計算する
  """
  def calculate_total(items) do
    items
    |> Enum.reduce(Decimal.new(0), fn item, acc ->
      subtotal = Decimal.mult(item.unit_price, Decimal.new(item.quantity))
      Decimal.add(acc, subtotal)
    end)
  end

  @doc """
  注文アイテムを追加する
  """
  def add_item(%__MODULE__{} = order, item) do
    updated_items = [item | order.items]
    %{order | 
      items: updated_items,
      total_amount: calculate_total(updated_items),
      updated_at: DateTime.utc_now()
    }
  end

  @doc """
  注文アイテムを削除する
  """
  def remove_item(%__MODULE__{} = order, product_id) do
    updated_items = Enum.reject(order.items, fn item -> 
      item.product_id == product_id 
    end)
    
    %{order | 
      items: updated_items,
      total_amount: calculate_total(updated_items),
      updated_at: DateTime.utc_now()
    }
  end
end
defmodule CommandService.Domain.Models.Product do
  @moduledoc """
  商品エンティティ

  コマンドサービス側で使用する商品のドメインモデル
  """

  @enforce_keys [:id, :name, :price, :stock_quantity, :category_id, :created_at]
  defstruct [
    :id,
    :name,
    :description,
    :price,
    :stock_quantity,
    :category_id,
    :created_at,
    :updated_at
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          description: String.t() | nil,
          price: Decimal.t(),
          stock_quantity: integer(),
          category_id: String.t(),
          created_at: DateTime.t(),
          updated_at: DateTime.t() | nil
        }

  @doc """
  新しい商品を作成する
  """
  @spec new(String.t(), String.t(), Decimal.t(), integer(), String.t(), String.t() | nil) ::
          {:ok, t()} | {:error, atom()}
  def new(id, name, price, stock_quantity, category_id, description \\ nil) do
    with :ok <- validate_name(name),
         :ok <- validate_price(price),
         :ok <- validate_stock_quantity(stock_quantity) do
      {:ok,
       %__MODULE__{
         id: id,
         name: name,
         description: description,
         price: price,
         stock_quantity: stock_quantity,
         category_id: category_id,
         created_at: DateTime.utc_now(),
         updated_at: DateTime.utc_now()
       }}
    end
  end

  @doc """
  商品情報を更新する
  """
  @spec update(t(), map()) :: {:ok, t()} | {:error, atom()}
  def update(%__MODULE__{} = product, attrs) do
    updated_product = %{product | updated_at: DateTime.utc_now()}

    updated_product =
      Enum.reduce(attrs, updated_product, fn
        {:name, value}, acc ->
          case validate_name(value) do
            :ok -> %{acc | name: value}
            _ -> acc
          end

        {:description, value}, acc ->
          %{acc | description: value}

        {:price, value}, acc ->
          case validate_price(value) do
            :ok -> %{acc | price: value}
            _ -> acc
          end

        {:category_id, value}, acc ->
          %{acc | category_id: value}

        _, acc ->
          acc
      end)

    {:ok, updated_product}
  end

  @doc """
  在庫を更新する
  """
  @spec update_stock(t(), integer()) :: {:ok, t()} | {:error, atom()}
  def update_stock(%__MODULE__{} = product, new_quantity) do
    case validate_stock_quantity(new_quantity) do
      :ok ->
        {:ok, %{product | stock_quantity: new_quantity, updated_at: DateTime.utc_now()}}

      error ->
        error
    end
  end

  @doc """
  在庫を減らす
  """
  @spec decrement_stock(t(), integer()) :: {:ok, t()} | {:error, atom()}
  def decrement_stock(%__MODULE__{stock_quantity: current} = product, quantity)
      when quantity > 0 do
    new_quantity = current - quantity

    if new_quantity >= 0 do
      update_stock(product, new_quantity)
    else
      {:error, :insufficient_stock}
    end
  end

  def decrement_stock(_product, _quantity), do: {:error, :invalid_quantity}

  @doc """
  在庫を増やす
  """
  @spec increment_stock(t(), integer()) :: {:ok, t()} | {:error, atom()}
  def increment_stock(%__MODULE__{stock_quantity: current} = product, quantity)
      when quantity > 0 do
    update_stock(product, current + quantity)
  end

  def increment_stock(_product, _quantity), do: {:error, :invalid_quantity}

  @doc """
  在庫があるかチェック
  """
  @spec in_stock?(t()) :: boolean()
  def in_stock?(%__MODULE__{stock_quantity: quantity}), do: quantity > 0

  @doc """
  指定数量の在庫があるかチェック
  """
  @spec has_stock?(t(), integer()) :: boolean()
  def has_stock?(%__MODULE__{stock_quantity: current}, required) when required > 0 do
    current >= required
  end

  def has_stock?(_product, _required), do: false

  # Private functions

  defp validate_name(name) when is_binary(name) and byte_size(name) > 0, do: :ok
  defp validate_name(_), do: {:error, :invalid_name}

  defp validate_price(%Decimal{} = price) do
    if Decimal.compare(price, Decimal.new(0)) == :gt do
      :ok
    else
      {:error, :invalid_price}
    end
  end

  defp validate_price(_), do: {:error, :invalid_price}

  defp validate_stock_quantity(quantity) when is_integer(quantity) and quantity >= 0, do: :ok
  defp validate_stock_quantity(_), do: {:error, :invalid_stock_quantity}
end

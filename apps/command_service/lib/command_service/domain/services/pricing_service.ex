defmodule CommandService.Domain.Services.PricingService do
  @moduledoc """
  価格計算ドメインサービス

  複雑な価格計算ロジックを集約する。
  """

  alias Shared.Domain.ValueObjects.Money

  @doc """
  注文アイテムの合計金額を計算する
  """
  @spec calculate_order_total(list(map()), String.t()) :: {:ok, Money.t()} | {:error, String.t()}
  def calculate_order_total(items, currency \\ "JPY") do
    items
    |> Enum.reduce_while({:ok, zero_money(currency)}, fn item, {:ok, acc} ->
      case calculate_item_subtotal(item, currency) do
        {:ok, subtotal} ->
          case Money.add(acc, subtotal) do
            {:ok, new_total} -> {:cont, {:ok, new_total}}
            error -> {:halt, error}
          end

        error ->
          {:halt, error}
      end
    end)
  end

  @doc """
  アイテムの小計を計算する
  """
  @spec calculate_item_subtotal(map(), String.t()) :: {:ok, Money.t()} | {:error, String.t()}
  def calculate_item_subtotal(item, currency \\ "JPY") do
    with {:ok, unit_price} <- get_unit_price(item, currency),
         {:ok, quantity} <- get_quantity(item) do
      Money.multiply(unit_price, quantity)
    end
  end

  @doc """
  割引を適用する
  """
  @spec apply_discount(Money.t(), map()) :: {:ok, Money.t()} | {:error, String.t()}
  def apply_discount(%Money{} = original_price, discount) do
    case discount.type do
      :percentage ->
        apply_percentage_discount(original_price, discount.value)

      :fixed ->
        apply_fixed_discount(original_price, discount.value, discount.currency)

      :coupon ->
        apply_coupon_discount(original_price, discount)

      _ ->
        {:error, "Unknown discount type"}
    end
  end

  @doc """
  税金を計算する
  """
  @spec calculate_tax(Money.t(), Decimal.t() | float()) :: {:ok, Money.t()} | {:error, String.t()}
  def calculate_tax(%Money{} = base_amount, tax_rate) when is_float(tax_rate) do
    calculate_tax(base_amount, Decimal.from_float(tax_rate))
  end

  def calculate_tax(%Money{} = base_amount, %Decimal{} = tax_rate) do
    if Decimal.compare(tax_rate, Decimal.new(0)) >= 0 do
      Money.multiply(base_amount, tax_rate)
    else
      {:error, "Tax rate must be non-negative"}
    end
  end

  @doc """
  送料を計算する
  """
  @spec calculate_shipping(list(map()), map(), String.t()) ::
          {:ok, Money.t()} | {:error, String.t()}
  def calculate_shipping(items, shipping_address, currency \\ "JPY") do
    total_weight = calculate_total_weight(items)
    zone = determine_shipping_zone(shipping_address)

    base_rate = get_shipping_rate(zone, currency)
    weight_charge = calculate_weight_charge(total_weight, zone, currency)

    with {:ok, base_money} <- Money.new(base_rate, currency),
         {:ok, weight_money} <- Money.new(weight_charge, currency) do
      Money.add(base_money, weight_money)
    end
  end

  @doc """
  価格階層に基づく単価を取得する
  """
  @spec get_tiered_price(integer(), list(map()), String.t()) ::
          {:ok, Money.t()} | {:error, String.t()}
  def get_tiered_price(quantity, price_tiers, currency \\ "JPY") do
    tier =
      price_tiers
      |> Enum.sort_by(& &1.min_quantity, :desc)
      |> Enum.find(fn tier -> quantity >= tier.min_quantity end)

    if tier do
      Money.new(tier.unit_price, currency)
    else
      {:error, "No applicable price tier found"}
    end
  end

  # Private functions

  defp zero_money(currency) do
    {:ok, money} = Money.new(0, currency)
    money
  end

  defp get_unit_price(%{unit_price: price}, currency) when is_number(price) do
    Money.new(price, currency)
  end

  defp get_unit_price(%{"unit_price" => price}, currency) when is_number(price) do
    Money.new(price, currency)
  end

  defp get_unit_price(_, _), do: {:error, "Invalid unit price"}

  defp get_quantity(%{quantity: qty}) when is_integer(qty) and qty > 0, do: {:ok, qty}
  defp get_quantity(%{"quantity" => qty}) when is_integer(qty) and qty > 0, do: {:ok, qty}
  defp get_quantity(_), do: {:error, "Invalid quantity"}

  defp apply_percentage_discount(price, percentage) when percentage >= 0 and percentage <= 100 do
    discount_rate = Decimal.div(Decimal.new(100 - percentage), Decimal.new(100))
    Money.multiply(price, Decimal.to_float(discount_rate))
  end

  defp apply_percentage_discount(_, _), do: {:error, "Invalid percentage discount"}

  defp apply_fixed_discount(price, discount_amount, discount_currency) do
    with {:ok, discount_money} <- Money.new(discount_amount, discount_currency) do
      Money.subtract(price, discount_money)
    end
  end

  defp apply_coupon_discount(price, %{code: _code, rules: _rules}) do
    # クーポンルールに基づく複雑な割引ロジック
    # 実際の実装では、クーポンサービスと連携
    {:ok, price}
  end

  defp calculate_total_weight(items) do
    Enum.reduce(items, 0, fn item, acc ->
      weight = Map.get(item, :weight, 0)
      quantity = Map.get(item, :quantity, 1)
      acc + weight * quantity
    end)
  end

  defp determine_shipping_zone(%{country: "JP", state_or_province: prefecture}) do
    # 都道府県に基づくゾーン判定
    cond do
      prefecture in ["東京都", "神奈川県", "千葉県", "埼玉県"] -> :zone_1
      prefecture in ["大阪府", "京都府", "兵庫県", "奈良県"] -> :zone_2
      true -> :zone_3
    end
  end

  defp determine_shipping_zone(%{country: country}) do
    # 国際配送のゾーン判定
    case country do
      "US" -> :international_1
      "CN" -> :international_2
      "KR" -> :international_2
      _ -> :international_3
    end
  end

  defp get_shipping_rate(:zone_1, "JPY"), do: 500
  defp get_shipping_rate(:zone_2, "JPY"), do: 700
  defp get_shipping_rate(:zone_3, "JPY"), do: 1000
  defp get_shipping_rate(:international_1, "JPY"), do: 3000
  defp get_shipping_rate(:international_2, "JPY"), do: 2500
  defp get_shipping_rate(:international_3, "JPY"), do: 4000
  defp get_shipping_rate(_, _), do: 1000

  defp calculate_weight_charge(weight, zone, "JPY") when weight > 5 do
    excess_weight = weight - 5

    rate_per_kg =
      case zone do
        :zone_1 -> 100
        :zone_2 -> 150
        :zone_3 -> 200
        :international_1 -> 500
        :international_2 -> 400
        :international_3 -> 600
      end

    excess_weight * rate_per_kg
  end

  defp calculate_weight_charge(_, _, _), do: 0
end

defmodule CommandService.Domain.Services.BusinessRulesService do
  @moduledoc """
  ビジネスルールを集約したドメインサービス

  複数のエンティティやアグリゲートにまたがるビジネスルールを管理する。
  """

  alias Shared.Domain.Errors.{BusinessRuleError, ValidationError}

  # 注文関連のビジネスルール

  @doc """
  注文可能かチェックする
  """
  @spec can_place_order?(map()) :: {:ok, :allowed} | {:error, atom(), map()}
  def can_place_order?(order_params) do
    with :ok <- validate_minimum_order_amount(order_params),
         :ok <- validate_maximum_items(order_params),
         :ok <- validate_business_hours(),
         :ok <- validate_customer_status(order_params[:user_id]),
         :ok <- validate_shipping_address(order_params[:shipping_address]) do
      {:ok, :allowed}
    end
  end

  @doc """
  注文キャンセル可能かチェックする
  """
  @spec can_cancel_order?(map()) :: {:ok, :allowed} | {:error, atom(), map()}
  def can_cancel_order?(order) do
    cond do
      order.status in [:shipped, :delivered] ->
        {:error, BusinessRuleError,
         %{
           rule: "cannot_cancel_shipped_order",
           context: %{order_id: order.id, status: order.status}
         }}

      hours_since_creation(order) > 24 ->
        {:error, BusinessRuleError,
         %{rule: "cancellation_time_exceeded", context: %{order_id: order.id, hours_limit: 24}}}

      true ->
        {:ok, :allowed}
    end
  end

  @doc """
  返品可能かチェックする
  """
  @spec can_return_order?(map()) :: {:ok, :allowed} | {:error, atom(), map()}
  def can_return_order?(order) do
    days_since_delivery = days_since_delivery(order)

    cond do
      order.status != :delivered ->
        {:error, BusinessRuleError,
         %{rule: "order_not_delivered", context: %{order_id: order.id, status: order.status}}}

      days_since_delivery > 30 ->
        {:error, BusinessRuleError,
         %{
           rule: "return_period_exceeded",
           context: %{order_id: order.id, days_limit: 30, days_passed: days_since_delivery}
         }}

      order.metadata[:non_returnable] ->
        {:error, BusinessRuleError,
         %{rule: "non_returnable_order", context: %{order_id: order.id}}}

      true ->
        {:ok, :allowed}
    end
  end

  # 在庫関連のビジネスルール

  @doc """
  在庫予約のビジネスルールをチェックする
  """
  @spec validate_inventory_reservation(String.t(), integer(), map()) ::
          :ok | {:error, atom(), map()}
  def validate_inventory_reservation(product_id, quantity, product_info) do
    with :ok <- validate_reservation_quantity_limit(quantity, product_info),
         :ok <- validate_product_availability(product_info) do
      validate_reservation_per_customer(product_id, quantity)
    end
  end

  # 価格関連のビジネスルール

  @doc """
  割引適用のビジネスルールをチェックする
  """
  @spec can_apply_discount?(map(), map()) :: {:ok, :allowed} | {:error, atom(), map()}
  def can_apply_discount?(discount, order) do
    with :ok <- validate_discount_period(discount),
         :ok <- validate_discount_usage_limit(discount),
         :ok <- validate_discount_conditions(discount, order),
         :ok <- validate_discount_combination(discount, order) do
      {:ok, :allowed}
    end
  end

  # 配送関連のビジネスルール

  @doc """
  配送可能かチェックする
  """
  @spec can_ship_to_address?(map()) :: {:ok, :allowed} | {:error, atom(), map()}
  def can_ship_to_address?(address) do
    # 配送制限国
    restricted_countries = ["XX", "YY"]

    cond do
      address.country in restricted_countries ->
        {:error, BusinessRuleError,
         %{rule: "shipping_restricted_country", context: %{country: address.country}}}

      requires_special_handling?(address) && !special_handling_available?() ->
        {:error, BusinessRuleError,
         %{rule: "special_handling_not_available", context: %{address: address}}}

      true ->
        {:ok, :allowed}
    end
  end

  # カスタマー関連のビジネスルール

  @doc """
  顧客の購入制限をチェックする
  """
  @spec check_customer_purchase_limits(String.t(), map()) ::
          :ok | {:error, atom(), map()}
  def check_customer_purchase_limits(customer_id, order_params) do
    with :ok <- check_daily_order_limit(customer_id),
         :ok <- check_monthly_spending_limit(customer_id, order_params) do
      check_blacklist_status(customer_id)
    end
  end

  # Private functions

  defp validate_minimum_order_amount(%{total_amount: amount}) do
    # 最低注文金額
    min_amount = 1000

    if amount >= min_amount do
      :ok
    else
      {:error, BusinessRuleError,
       %{rule: "minimum_order_amount", context: %{minimum: min_amount, actual: amount}}}
    end
  end

  defp validate_maximum_items(%{items: items}) do
    max_items = 50
    item_count = length(items)

    if item_count <= max_items do
      :ok
    else
      {:error, BusinessRuleError,
       %{rule: "maximum_items_exceeded", context: %{maximum: max_items, actual: item_count}}}
    end
  end

  defp validate_business_hours do
    current_hour = DateTime.utc_now() |> DateTime.to_time() |> Map.get(:hour)

    if current_hour >= 9 && current_hour < 21 do
      :ok
    else
      {:error, BusinessRuleError,
       %{
         rule: "outside_business_hours",
         context: %{current_hour: current_hour, business_hours: "9:00-21:00"}
       }}
    end
  end

  defp validate_customer_status(_customer_id) do
    # 実際の実装では顧客サービスと連携
    :ok
  end

  defp validate_shipping_address(nil) do
    {:error, ValidationError, %{field: "shipping_address", reason: "required"}}
  end

  defp validate_shipping_address(_address) do
    :ok
  end

  defp hours_since_creation(order) do
    case order.created_at do
      %DateTime{} = created_at ->
        DateTime.diff(DateTime.utc_now(), created_at, :hour)

      _ ->
        0
    end
  end

  defp days_since_delivery(order) do
    case order.delivered_at do
      %DateTime{} = delivered_at ->
        DateTime.diff(DateTime.utc_now(), delivered_at, :day)

      _ ->
        0
    end
  end

  defp validate_reservation_quantity_limit(quantity, %{max_reservation: max}) do
    if quantity <= max do
      :ok
    else
      {:error, BusinessRuleError,
       %{rule: "reservation_quantity_exceeded", context: %{maximum: max, requested: quantity}}}
    end
  end

  defp validate_product_availability(%{status: status}) do
    if status == :active do
      :ok
    else
      {:error, BusinessRuleError, %{rule: "product_not_available", context: %{status: status}}}
    end
  end

  defp validate_reservation_per_customer(_product_id, _quantity) do
    # 実際の実装では顧客ごとの予約履歴をチェック
    :ok
  end

  defp validate_discount_period(%{valid_from: from, valid_to: to})
       when is_struct(from, DateTime) and is_struct(to, DateTime) do
    now = DateTime.utc_now()

    if DateTime.compare(now, from) in [:eq, :gt] && DateTime.compare(now, to) in [:eq, :lt] do
      :ok
    else
      {:error, BusinessRuleError,
       %{
         rule: "discount_period_invalid",
         context: %{valid_from: from, valid_to: to, current: now}
       }}
    end
  end

  defp validate_discount_period(_) do
    {:error, BusinessRuleError,
     %{rule: "invalid_discount_period", context: %{reason: "Invalid date format"}}}
  end

  defp validate_discount_usage_limit(%{usage_limit: limit, usage_count: count}) do
    if count < limit do
      :ok
    else
      {:error, BusinessRuleError,
       %{rule: "discount_usage_limit_reached", context: %{limit: limit, count: count}}}
    end
  end

  defp validate_discount_conditions(%{min_amount: min}, %{total_amount: total}) do
    if total >= min do
      :ok
    else
      {:error, BusinessRuleError,
       %{rule: "discount_minimum_amount_not_met", context: %{minimum: min, actual: total}}}
    end
  end

  defp validate_discount_combination(%{exclusive: true}, %{discounts: discounts})
       when length(discounts) > 0 do
    {:error, BusinessRuleError,
     %{rule: "exclusive_discount_conflict", context: %{existing_discounts: length(discounts)}}}
  end

  defp validate_discount_combination(_, _), do: :ok

  defp requires_special_handling?(%{country: country}) do
    # 南極、スバールバル諸島など
    country in ["AQ", "SJ"]
  end

  defp special_handling_available? do
    # 実際の実装では配送サービスの能力をチェック
    false
  end

  defp check_daily_order_limit(_customer_id) do
    # 実際の実装では本日の注文数をチェック
    :ok
  end

  defp check_monthly_spending_limit(_customer_id, %{total_amount: _amount}) do
    # 実際の実装では月間購入額をチェック
    :ok
  end

  defp check_blacklist_status(_customer_id) do
    # 実際の実装ではブラックリストをチェック
    :ok
  end
end

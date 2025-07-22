defmodule QueryService.Infrastructure.Repositories.OrderRepository do
  @moduledoc """
  注文読み取りモデルのリポジトリ実装（Firestore版）
  """

  alias QueryService.Domain.ReadModels.Order
  alias Shared.Infrastructure.Firestore.Repository
  require Logger

  @collection "read_orders"

  @doc """
  注文を保存する（プロジェクション用）
  """
  def save(%Order{} = order) do
    data = %{
      id: order.id,
      customer_id: order.customer_id,
      status: to_string(order.status),
      items: Enum.map(order.items, &item_to_map/1),
      total_amount: Decimal.to_float(order.total_amount),
      currency: order.currency,
      shipping_address: order.shipping_address,
      created_at: order.created_at,
      updated_at: DateTime.utc_now(),
      confirmed_at: order.confirmed_at,
      shipped_at: order.shipped_at,
      delivered_at: order.delivered_at,
      cancelled_at: order.cancelled_at
    }

    case Repository.save(@collection, order.id, data) do
      {:ok, _} -> {:ok, order}
      error -> error
    end
  end

  @doc """
  ID で注文を取得する
  """
  def get(id) do
    case Repository.get(@collection, id) do
      {:ok, data} -> 
        order = build_order_from_data(data)
        {:ok, order}
      
      error -> 
        error
    end
  end

  @doc """
  注文を検索する
  """
  def get_all(filters \\ %{}) do
    opts = build_query_opts(filters)
    
    case Repository.list(@collection, opts) do
      {:ok, data_list} ->
        orders = Enum.map(data_list, &build_order_from_data/1)
        
        # フィルタリング
        filtered = apply_filters(orders, filters)
        
        # ソート処理
        sorted = apply_sorting(filtered, filters)
        
        {:ok, sorted}
      
      error -> 
        error
    end
  end

  @doc """
  顧客IDで注文を検索する
  """
  def find_by_customer(customer_id) do
    case get_all(%{customer_id: customer_id}) do
      {:ok, orders} -> {:ok, orders}
      error -> error
    end
  end

  @doc """
  ステータスで注文を検索する
  """
  def find_by_status(status) do
    case get_all(%{status: status}) do
      {:ok, orders} -> {:ok, orders}
      error -> error
    end
  end

  @doc """
  注文を削除する
  """
  def delete(id) do
    Repository.delete(@collection, id)
  end

  @doc """
  すべてのプロジェクションをクリアする
  """
  def clear_all do
    case get_all() do
      {:ok, orders} ->
        Enum.each(orders, fn order ->
          delete(order.id)
        end)
        {:ok, length(orders)}
      
      error -> 
        error
    end
  end

  @doc """
  注文を作成する
  """
  def create(attrs) do
    order = struct(Order, attrs)
    save(order)
  end

  @doc """
  注文を更新する
  """
  def update(id, attrs) do
    with {:ok, order} <- get(id) do
      updated = struct(order, attrs)
      save(updated)
    end
  end

  @doc """
  すべて削除（delete_all）
  """
  def delete_all do
    clear_all()
  end

  @doc """
  検索（search）
  """
  def search(filters) do
    get_all(filters)
  end

  # Private functions

  defp build_order_from_data(data) do
    %Order{
      id: data["id"] || data[:id],
      customer_id: data["customer_id"] || data[:customer_id],
      status: parse_status(data["status"] || data[:status]),
      items: parse_items(data["items"] || data[:items] || []),
      total_amount: parse_decimal(data["total_amount"] || data[:total_amount]),
      currency: data["currency"] || data[:currency] || "JPY",
      shipping_address: data["shipping_address"] || data[:shipping_address],
      created_at: parse_datetime(data["created_at"] || data[:created_at]),
      updated_at: parse_datetime(data["updated_at"] || data[:updated_at]),
      confirmed_at: parse_datetime(data["confirmed_at"] || data[:confirmed_at]),
      shipped_at: parse_datetime(data["shipped_at"] || data[:shipped_at]),
      delivered_at: parse_datetime(data["delivered_at"] || data[:delivered_at]),
      cancelled_at: parse_datetime(data["cancelled_at"] || data[:cancelled_at])
    }
  end

  defp item_to_map(item) do
    %{
      product_id: item.product_id,
      product_name: item.product_name,
      quantity: item.quantity,
      unit_price: Decimal.to_float(item.unit_price),
      subtotal: Decimal.to_float(item.subtotal)
    }
  end

  defp parse_items(items) when is_list(items) do
    Enum.map(items, fn item ->
      %Order.Item{
        product_id: item["product_id"] || item[:product_id],
        product_name: item["product_name"] || item[:product_name],
        quantity: item["quantity"] || item[:quantity] || 0,
        unit_price: parse_decimal(item["unit_price"] || item[:unit_price]),
        subtotal: parse_decimal(item["subtotal"] || item[:subtotal])
      }
    end)
  end
  defp parse_items(_), do: []

  defp parse_status("pending"), do: :pending
  defp parse_status("confirmed"), do: :confirmed
  defp parse_status("shipped"), do: :shipped
  defp parse_status("delivered"), do: :delivered
  defp parse_status("cancelled"), do: :cancelled
  defp parse_status(_), do: :pending

  defp build_query_opts(filters) do
    opts = []
    
    # ページネーション
    opts = if Map.has_key?(filters, :limit), do: [{:limit, filters.limit} | opts], else: opts
    opts = if Map.has_key?(filters, :offset), do: [{:offset, filters.offset} | opts], else: opts
    
    opts
  end

  defp apply_filters(orders, filters) do
    orders
    |> filter_by_customer(filters[:customer_id])
    |> filter_by_status(filters[:status])
    |> filter_by_date_range(filters[:from_date], filters[:to_date])
  end

  defp filter_by_customer(orders, nil), do: orders
  defp filter_by_customer(orders, customer_id) do
    Enum.filter(orders, fn order -> 
      order.customer_id == customer_id 
    end)
  end

  defp filter_by_status(orders, nil), do: orders
  defp filter_by_status(orders, status) do
    Enum.filter(orders, fn order -> 
      order.status == status 
    end)
  end

  defp filter_by_date_range(orders, nil, nil), do: orders
  defp filter_by_date_range(orders, from_date, to_date) do
    orders
    |> filter_by_from_date(from_date)
    |> filter_by_to_date(to_date)
  end

  defp filter_by_from_date(orders, nil), do: orders
  defp filter_by_from_date(orders, from_date) do
    Enum.filter(orders, fn order ->
      DateTime.compare(order.created_at, from_date) in [:gt, :eq]
    end)
  end

  defp filter_by_to_date(orders, nil), do: orders
  defp filter_by_to_date(orders, to_date) do
    Enum.filter(orders, fn order ->
      DateTime.compare(order.created_at, to_date) in [:lt, :eq]
    end)
  end

  defp apply_sorting(orders, %{sort_by: field, sort_order: order}) do
    Enum.sort_by(orders, &Map.get(&1, field), order_to_fun(order))
  end
  defp apply_sorting(orders, _), do: orders

  defp order_to_fun(:asc), do: &<=/2
  defp order_to_fun(:desc), do: &>=/2
  defp order_to_fun(_), do: &<=/2

  defp parse_decimal(nil), do: Decimal.new(0)
  defp parse_decimal(value) when is_float(value), do: Decimal.from_float(value)
  defp parse_decimal(value) when is_integer(value), do: Decimal.new(value)
  defp parse_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, _} -> decimal
      :error -> Decimal.new(0)
    end
  end
  defp parse_decimal(_), do: Decimal.new(0)

  defp parse_datetime(nil), do: nil
  defp parse_datetime(%DateTime{} = dt), do: dt
  defp parse_datetime(string) when is_binary(string) do
    case DateTime.from_iso8601(string) do
      {:ok, datetime, _} -> datetime
      _ -> nil
    end
  end
  defp parse_datetime(_), do: nil
end
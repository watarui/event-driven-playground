defmodule CommandService.Infrastructure.Repositories.OrderRepository do
  @moduledoc """
  注文エンティティのリポジトリ実装（Firestore版）
  """

  alias CommandService.Domain.Models.Order
  alias Shared.Infrastructure.Firestore.Repository
  require Logger

  @collection "orders"

  @doc """
  注文を保存する
  """
  def save(%Order{} = order) do
    data = %{
      id: order.id,
      customer_id: order.customer_id,
      items: Enum.map(order.items, &item_to_map/1),
      total_amount: Decimal.to_float(order.total_amount),
      currency: order.currency || "JPY",
      status: to_string(order.status),
      created_at: order.created_at,
      updated_at: DateTime.utc_now()
    }

    case Repository.save(@collection, order.id, data) do
      {:ok, _} -> {:ok, order}
      error -> error
    end
  end

  @doc """
  ID で注文を取得する
  """
  def find_by_id(id) do
    case Repository.get(@collection, id) do
      {:ok, data} ->
        order = build_order_from_data(data)
        {:ok, order}

      error ->
        error
    end
  end

  @doc """
  複数の ID で注文を取得する
  """
  def find_by_ids(ids) when is_list(ids) do
    orders =
      Enum.reduce(ids, [], fn id, acc ->
        case find_by_id(id) do
          {:ok, order} -> [order | acc]
          _ -> acc
        end
      end)

    {:ok, Enum.reverse(orders)}
  end

  @doc """
  条件で注文を検索する
  """
  def find_by(criteria) do
    # TODO: Firestore のクエリ機能を使用して最適化
    case Repository.list(@collection, []) do
      {:ok, data_list} ->
        orders = Enum.map(data_list, &build_order_from_data/1)
        filtered = apply_criteria(orders, criteria)
        {:ok, filtered}

      error ->
        error
    end
  end

  @doc """
  注文が存在するかチェック
  """
  def exists?(order_id) do
    case find_by_id(order_id) do
      {:ok, _} -> true
      _ -> false
    end
  end

  @doc """
  トランザクション実行（Firestore版）
  """
  def transaction(fun) do
    # Firestore のトランザクションは現在の実装では限定的なため、
    # 関数を直接実行
    try do
      fun.()
    rescue
      e ->
        Logger.error("Transaction failed: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc """
  注文を削除する
  """
  def delete(id) do
    Repository.delete(@collection, id)
  end

  # Private functions

  defp build_order_from_data(data) do
    %Order{
      id: data["id"] || data[:id],
      customer_id: data["customer_id"] || data[:customer_id],
      items: parse_items(data["items"] || data[:items] || []),
      total_amount: parse_decimal(data["total_amount"] || data[:total_amount]),
      currency: data["currency"] || data[:currency] || "JPY",
      status: parse_status(data["status"] || data[:status]),
      created_at: parse_datetime(data["created_at"] || data[:created_at]),
      updated_at: parse_datetime(data["updated_at"] || data[:updated_at])
    }
  end

  defp item_to_map(item) do
    %{
      product_id: item.product_id,
      quantity: item.quantity,
      unit_price: Decimal.to_float(item.unit_price)
    }
  end

  defp parse_items(items) when is_list(items) do
    Enum.map(items, fn item ->
      %Order.Item{
        product_id: item["product_id"] || item[:product_id],
        quantity: item["quantity"] || item[:quantity] || 0,
        unit_price: parse_decimal(item["unit_price"] || item[:unit_price])
      }
    end)
  end

  defp parse_items(_), do: []

  defp parse_status("pending"), do: :pending
  defp parse_status("confirmed"), do: :confirmed
  defp parse_status("cancelled"), do: :cancelled
  defp parse_status(:pending), do: :pending
  defp parse_status(:confirmed), do: :confirmed
  defp parse_status(:cancelled), do: :cancelled
  defp parse_status(_), do: :pending

  defp apply_criteria(orders, criteria) do
    orders
    |> filter_by_customer(criteria[:customer_id])
    |> filter_by_status(criteria[:status])
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

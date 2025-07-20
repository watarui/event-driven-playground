defmodule ClientService.GraphQL.Resolvers.OrderResolverPubsub do
  @moduledoc """
  注文関連の GraphQL リゾルバー (PubSub版)
  """

  alias ClientService.Infrastructure.{RemoteCommandBus, RemoteQueryBus}
  import Shared.GraphQL.ErrorHelpers

  require Logger

  @doc """
  注文を作成（SAGAを開始）
  """
  def create_order(_parent, %{input: input}, %{context: context} = _resolution) do
    # 認証されたユーザーの情報を使用
    current_user = Map.get(context, :current_user, %{})
    user_id = Map.get(current_user, :user_id, input.user_id)
    
    command = %{
      __struct__: "CommandService.Application.Commands.OrderCommands.CreateOrder",
      command_type: "order.create",
      user_id: user_id,
      items: Enum.map(input.items, &transform_order_item/1),
      metadata: %{
        created_by: user_id,
        user_role: Map.get(current_user, :role, :reader)
      }
    }

    case RemoteCommandBus.send_command(command) do
      {:ok, result} when is_map(result) ->
        # order_id を文字列キーとアトムキーの両方で取得を試みる
        order_id = result["order_id"] || result[:order_id]

        if order_id do
          # SAGAが開始され、注文が作成された
          # 注文詳細を取得して返す
          order = %{
            id: order_id,
            user_id: input.user_id,
            # 初期状態はpending
            status: :pending,
            total_amount: calculate_total_amount(input.items),
            items: Enum.map(input.items, &transform_input_item/1),
            created_at: DateTime.utc_now(),
            updated_at: DateTime.utc_now()
          }

          saga_id = result["saga_id"] || result[:saga_id] || "Not available"
          Logger.info("Order created with id: #{order_id}, saga_id: #{saga_id}")
          {:ok, %{success: true, order: order, message: "Order created successfully"}}
        else
          Logger.error("No order_id in command result: #{inspect(result)}")
          {:error, "Failed to create order: no order_id returned"}
        end

      # RemoteCommandBusが直接結果を返すケース
      %{order_id: order_id} = result when is_map(result) ->
        order = %{
          id: order_id,
          user_id: input.user_id,
          status: :pending,
          total_amount: calculate_total_amount(input.items),
          items: Enum.map(input.items, &transform_input_item/1),
          created_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }

        saga_id = result[:saga_id] || "Not available"
        Logger.info("Order created with id: #{order_id}, saga_id: #{saga_id}")
        {:ok, %{success: true, order: order, message: "Order created successfully"}}

      error ->
        handle_command_error(error, "Failed to create order")
    end
  end

  @doc """
  注文を取得
  """
  def get_order(_parent, %{id: id}, _resolution) do
    query = %{
      __struct__: "QueryService.Application.Queries.OrderQueries.GetOrder",
      query_type: "order.get",
      id: id,
      metadata: nil
    }

    RemoteQueryBus.send_query(query)
    |> with_transform(&transform_order/1, "Failed to get order")
  end

  @doc """
  注文一覧を取得
  """
  def list_orders(_parent, args, _resolution) do
    query = %{
      __struct__: "QueryService.Application.Queries.OrderQueries.ListOrders",
      query_type: "order.list",
      limit: Map.get(args, :limit, 20),
      offset: Map.get(args, :offset, 0),
      user_id: Map.get(args, :user_id),
      status: Map.get(args, :status),
      metadata: nil
    }

    RemoteQueryBus.send_query(query)
    |> with_list_transform(&transform_order/1, "Failed to list orders")
  end

  @doc """
  ユーザーの注文一覧を取得
  """
  def list_user_orders(_parent, %{user_id: user_id} = args, _resolution) do
    query = %{
      __struct__: "QueryService.Application.Queries.OrderQueries.ListUserOrders",
      query_type: "order.list_by_user",
      user_id: user_id,
      limit: Map.get(args, :limit, 20),
      offset: Map.get(args, :offset, 0),
      metadata: nil
    }

    RemoteQueryBus.send_query(query)
    |> with_list_transform(&transform_order/1, "Failed to list user orders")
  end

  # プライベート関数

  defp transform_order_item(item) do
    %{
      product_id: item.product_id,
      product_name: item.product_name,
      quantity: item.quantity,
      # Decimal変換を削除
      unit_price: item.unit_price
    }
  end

  defp transform_input_item(item) do
    %{
      product_id: item.product_id,
      product_name: item.product_name,
      quantity: item.quantity,
      unit_price: item.unit_price,
      subtotal: Decimal.mult(Decimal.new(item.unit_price), Decimal.new(item.quantity))
    }
  end

  defp calculate_total_amount(items) do
    items
    |> Enum.reduce(Decimal.new(0), fn item, acc ->
      subtotal = Decimal.mult(item.unit_price, item.quantity)
      Decimal.add(acc, subtotal)
    end)
  end

  defp transform_order(order) do
    %{
      id: order.id,
      user_id: order.user_id,
      status: String.to_atom(order.status),
      total_amount: order.total_amount,
      items: Enum.map(order.items || [], &transform_order_item_from_read/1),
      created_at: ensure_datetime(order.inserted_at),
      updated_at: ensure_datetime(order.updated_at),
      saga_id: order.saga_id,
      saga_status: order.saga_status && String.to_atom(order.saga_status),
      saga_current_step: order.saga_current_step,
      payment_id: order.payment_id,
      shipping_id: order.shipping_id
    }
  end

  defp transform_order_item_from_read(item) do
    %{
      product_id: item["product_id"] || item[:product_id],
      product_name: item["product_name"] || item[:product_name],
      quantity: item["quantity"] || item[:quantity],
      unit_price: Decimal.new(item["unit_price"] || item[:unit_price] || "0"),
      subtotal: Decimal.new(item["subtotal"] || item[:subtotal] || "0")
    }
  end

  defp ensure_datetime(%DateTime{} = datetime), do: datetime

  defp ensure_datetime(%NaiveDateTime{} = naive_datetime) do
    DateTime.from_naive!(naive_datetime, "Etc/UTC")
  end

  defp ensure_datetime(nil), do: nil

end

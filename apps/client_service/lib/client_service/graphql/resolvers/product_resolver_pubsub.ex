defmodule ClientService.GraphQL.Resolvers.ProductResolverPubsub do
  @moduledoc """
  商品関連の GraphQL リゾルバー (PubSub版)
  """

  alias ClientService.Infrastructure.{RemoteCommandBus, RemoteQueryBus}
  import Shared.GraphQL.ErrorHelpers

  require Logger

  @doc """
  商品を取得
  """
  def get_product(_parent, %{id: id}, _resolution) do
    query = %{
      __struct__: "QueryService.Application.Queries.ProductQueries.GetProduct",
      query_type: "product.get",
      id: id,
      metadata: nil
    }

    RemoteQueryBus.send_query(query)
    |> with_transform(&transform_product/1, "Failed to get product")
  end

  @doc """
  商品一覧を取得
  """
  def list_products(_parent, args, _resolution) do
    query = %{
      __struct__: "QueryService.Application.Queries.ProductQueries.ListProducts",
      query_type: "product.list",
      limit: Map.get(args, :limit, 20),
      offset: Map.get(args, :offset, 0),
      metadata: nil
    }

    RemoteQueryBus.send_query(query)
    |> with_list_transform(&transform_product/1, "Failed to list products")
  end

  @doc """
  カテゴリ別に商品を取得
  """
  def list_products_by_category(_parent, %{category_id: category_id} = args, _resolution) do
    query = %{
      __struct__: "QueryService.Application.Queries.ProductQueries.ListProducts",
      query_type: "product.list",
      category_id: category_id,
      limit: Map.get(args, :limit, 20),
      offset: Map.get(args, :offset, 0),
      metadata: nil
    }

    RemoteQueryBus.send_query(query)
    |> with_list_transform(&transform_product/1, "Failed to list products by category")
  end

  @doc """
  商品を検索
  """
  def search_products(_parent, %{search_term: search_term} = args, _resolution) do
    query = %{
      __struct__: "QueryService.Application.Queries.ProductQueries.SearchProducts",
      query_type: "product.search",
      search_term: search_term,
      limit: Map.get(args, :limit, 20),
      offset: Map.get(args, :offset, 0),
      metadata: nil
    }

    RemoteQueryBus.send_query(query)
    |> with_list_transform(&transform_product/1, "Failed to search products")
  end

  @doc """
  商品を作成
  """
  def create_product(_parent, %{input: input}, _resolution) do
    command = %{
      __struct__: "CommandService.Application.Commands.ProductCommands.CreateProduct",
      command_type: "product.create",
      name: input.name,
      price: input.price,
      category_id: input.category_id,
      metadata: %{
        description: Map.get(input, :description, ""),
        stock_quantity: Map.get(input, :stock_quantity, 0)
      }
    }

    case RemoteCommandBus.send_command(command) do
      {:ok, %{__struct__: _} = aggregate} ->
        transform_aggregate_to_response(aggregate)

      %{__struct__: _} = aggregate ->
        # RemoteCommandBusが直接アグリゲートを返すケース
        transform_aggregate_to_response(aggregate)

      error ->
        handle_command_error(error, "Failed to create product")
    end
  end

  @doc """
  商品を更新
  """
  def update_product(_parent, %{id: id, input: input}, _resolution) do
    command = %{
      __struct__: "CommandService.Application.Commands.ProductCommands.UpdateProduct",
      command_type: "product.update",
      id: id,
      name: Map.get(input, :name),
      price: Map.get(input, :price),
      category_id: Map.get(input, :category_id),
      metadata: %{
        description: Map.get(input, :description),
        stock_quantity: Map.get(input, :stock_quantity)
      }
    }

    case RemoteCommandBus.send_command(command) do
      {:ok, aggregate} ->
        transform_aggregate_to_response(aggregate)

      error ->
        handle_command_error(error, "Failed to update product")
    end
  end

  @doc """
  商品を削除
  """
  def delete_product(_parent, %{id: id}, _resolution) do
    command = %{
      __struct__: "CommandService.Application.Commands.ProductCommands.DeleteProduct",
      command_type: "product.delete",
      id: id,
      metadata: %{}
    }

    case RemoteCommandBus.send_command(command) do
      {:ok, _} ->
        {:ok, %{success: true, message: "Product deleted successfully"}}

      error ->
        handle_command_error(error, "Failed to delete product")
    end
  end

  @doc """
  商品価格を変更
  """
  def change_product_price(_parent, %{id: id, new_price: new_price}, _resolution) do
    command = %{
      __struct__: "CommandService.Application.Commands.ProductCommands.ChangeProductPrice",
      command_type: "product.change_price",
      id: id,
      new_price: new_price,
      metadata: %{}
    }

    case RemoteCommandBus.send_command(command) do
      {:ok, aggregate} ->
        transform_aggregate_to_response(aggregate)

      error ->
        handle_command_error(error, "Failed to change product price")
    end
  end

  @doc """
  在庫を更新
  """
  def update_stock(_parent, %{id: id, quantity: quantity}, _resolution) do
    command = %{
      __struct__: "CommandService.Application.Commands.ProductCommands.UpdateStock",
      command_type: "product.update_stock",
      product_id: id,
      quantity: quantity,
      metadata: %{}
    }

    case RemoteCommandBus.send_command(command) do
      {:ok, aggregate} ->
        {:ok,
         %{
           id: aggregate.id.value,
           stock_quantity: aggregate.stock_quantity
         }}

      error ->
        handle_command_error(error, "Failed to update stock")
    end
  end

  # プライベート関数

  defp get_value(%{value: value}), do: value
  defp get_value(value), do: value

  defp transform_aggregate_to_response(aggregate) do
    {:ok,
     %{
       id: get_value(aggregate.id),
       name: get_value(aggregate.name),
       description: aggregate.description || "",
       price: aggregate.price.amount,
       currency: aggregate.price.currency || "JPY",
       stock_quantity: aggregate.stock_quantity || 0,
       category_id: aggregate.category_id && get_value(aggregate.category_id),
       active: Map.get(aggregate, :active, true),
       created_at: aggregate.created_at,
       updated_at: aggregate.updated_at
     }}
  end

  defp transform_product(product) do
    %{
      id: product.id,
      name: product.name,
      description: product.description,
      price: product.price,
      # デフォルトで JPY を設定
      currency: Map.get(product, :currency, "JPY"),
      stock_quantity: product.stock_quantity,
      category_id: product.category_id,
      category_name: product.category_name,
      # active フィールドも追加
      active: Map.get(product, :active, true),
      created_at: ensure_datetime(product.created_at),
      updated_at: ensure_datetime(product.updated_at)
    }
  end

  defp ensure_datetime(%DateTime{} = datetime), do: datetime

  defp ensure_datetime(%NaiveDateTime{} = naive_datetime) do
    DateTime.from_naive!(naive_datetime, "Etc/UTC")
  end

  defp ensure_datetime(nil), do: nil
end

defmodule QueryService.Infrastructure.Projections.ProductProjection do
  @moduledoc """
  商品プロジェクション

  商品関連のイベントを処理し、Read Model を更新します
  """

  alias QueryService.Infrastructure.Cache
  alias QueryService.Infrastructure.Repositories.ProductRepository

  alias Shared.Domain.Events.ProductEvents.{
    ProductCreated,
    ProductUpdated,
    ProductPriceChanged,
    ProductDeleted
  }

  require Logger

  @doc """
  イベントを処理する
  """
  def handle_event(%ProductCreated{} = event) do
    # カテゴリ名を取得
    category_name = get_category_name(event.category_id.value)

    attrs = %{
      id: event.id.value,
      name: event.name.value,
      description: event.description,
      price_amount: Decimal.new(to_string(event.price.amount)),
      price_currency: event.price.currency,
      stock_quantity: event.stock_quantity,
      category_id: event.category_id.value,
      category_name: category_name,
      active: true,
      metadata: %{},
      inserted_at: event.created_at,
      updated_at: event.created_at
    }

    case ProductRepository.create(attrs) do
      {:ok, product} ->
        Logger.info("Product projection created: #{product.id}")
        # キャッシュを無効化
        Cache.delete_pattern("products:*")
        {:ok, product}

      {:error, reason} ->
        Logger.error("Failed to create product projection: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_event(%ProductUpdated{} = event) do
    attrs = %{
      name: event.name.value,
      description: event.description,
      category_id: event.category_id.value,
      updated_at: event.updated_at
    }

    case ProductRepository.update(event.id.value, attrs) do
      {:ok, product} ->
        Logger.info("Product projection updated: #{product.id}")
        # 関連するキャッシュを無効化
        Cache.delete("product:#{product.id}")
        Cache.delete_pattern("products:*")
        {:ok, product}

      {:error, reason} ->
        Logger.error("Failed to update product projection: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_event(%ProductPriceChanged{} = event) do
    attrs = %{
      price_amount: Decimal.new(to_string(event.new_price.amount)),
      updated_at: event.changed_at
    }

    case ProductRepository.update(event.id.value, attrs) do
      {:ok, product} ->
        Logger.info("Product price updated: #{product.id}")
        # 関連するキャッシュを無効化
        Cache.delete("product:#{product.id}")
        Cache.delete_pattern("products:*")
        {:ok, product}

      {:error, reason} ->
        Logger.error("Failed to update product price: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # StockUpdated イベントは今後実装予定
  # def handle_event(%StockUpdated{} = event) do
  #   ...
  # end

  def handle_event(%ProductDeleted{} = event) do
    case ProductRepository.delete(event.id.value) do
      {:ok, _} ->
        Logger.info("Product projection deleted: #{event.id.value}")
        # 関連するキャッシュを無効化
        Cache.delete("product:#{event.id.value}")
        Cache.delete_pattern("products:*")
        :ok

      {:error, reason} ->
        Logger.error("Failed to delete product projection: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_event(_event) do
    # 他のイベントは無視
    :ok
  end

  @doc """
  すべての商品プロジェクションをクリアする
  """
  def clear_all do
    ProductRepository.delete_all()
  end

  # Private functions

  defp get_category_name(category_id) do
    alias QueryService.Infrastructure.Repositories.CategoryRepository

    case CategoryRepository.get(category_id) do
      {:ok, category} -> category.name
      {:error, _} -> nil
    end
  end
end

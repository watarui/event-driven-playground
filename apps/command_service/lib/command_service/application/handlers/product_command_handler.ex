defmodule CommandService.Application.Handlers.ProductCommandHandler do
  @moduledoc """
  商品コマンドハンドラー

  商品に関するコマンドを処理し、ドメインロジックを実行します。
  """

  alias CommandService.Domain.Aggregates.ProductAggregate
  alias CommandService.Infrastructure.Repositories.{ProductRepository, CategoryRepository}
  alias CommandService.Infrastructure.UnitOfWork
  alias Shared.Infrastructure.EventBus

  alias CommandService.Application.Commands.ProductCommands.{
    CreateProduct,
    UpdateProduct,
    DeleteProduct,
    ChangeProductPrice,
    UpdateStock,
    ReserveStock,
    ReleaseStock
  }

  require Logger

  @doc """
  商品作成コマンドを処理する
  """
  def handle(%CreateProduct{} = command) do
    UnitOfWork.transaction_with_events(fn ->
      # カテゴリの存在確認
      with {:ok, _category} <- CategoryRepository.get(command.category_id),
           # 新しい商品アグリゲートを作成
           aggregate = ProductAggregate.new(),
           # コマンドを実行
           {:ok, updated_aggregate, events} <- ProductAggregate.execute(aggregate, command),
           # アグリゲートを保存
           {:ok, _} <- ProductRepository.save(updated_aggregate) do
        # イベントを UnitOfWork に追加
        UnitOfWork.add_events(events)
        # イベントを発行
        Enum.each(events, &EventBus.publish_event/1)
        {:ok, updated_aggregate}
      else
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  def handle(%UpdateProduct{} = command) do
    UnitOfWork.transaction_with_events(fn ->
      # 既存の商品を取得
      with {:ok, aggregate} <- ProductRepository.get(command.id),
           # カテゴリを変更する場合は存在確認
           :ok <- validate_category_change(command),
           # コマンドを実行
           {:ok, updated_aggregate, events} <- ProductAggregate.execute(aggregate, command),
           # アグリゲートを保存
           {:ok, _} <- ProductRepository.save(updated_aggregate) do
        # イベントを UnitOfWork に追加
        UnitOfWork.add_events(events)
        # イベントを発行
        Enum.each(events, &EventBus.publish_event/1)
        {:ok, updated_aggregate}
      else
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  def handle(%DeleteProduct{} = command) do
    UnitOfWork.transaction_with_events(fn ->
      # 既存の商品を取得
      with {:ok, aggregate} <- ProductRepository.get(command.id),
           # 削除可能かチェック（在庫が0か）
           :ok <- check_can_delete(aggregate),
           # コマンドを実行
           {:ok, updated_aggregate, events} <- ProductAggregate.execute(aggregate, command),
           # アグリゲートを保存
           {:ok, _} <- ProductRepository.save(updated_aggregate) do
        # イベントを UnitOfWork に追加
        UnitOfWork.add_events(events)
        # イベントを発行
        Enum.each(events, &EventBus.publish_event/1)
        {:ok, updated_aggregate}
      else
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  def handle(%ChangeProductPrice{} = command) do
    UnitOfWork.transaction_with_events(fn ->
      with {:ok, aggregate} <- ProductRepository.get(command.id),
           {:ok, updated_aggregate, events} <- ProductAggregate.execute(aggregate, command),
           {:ok, _} <- ProductRepository.save(updated_aggregate) do
        UnitOfWork.add_events(events)
        Enum.each(events, &EventBus.publish_event/1)
        {:ok, updated_aggregate}
      else
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  def handle(%UpdateStock{} = command) do
    UnitOfWork.transaction_with_events(fn ->
      with {:ok, aggregate} <- ProductRepository.get(command.product_id),
           {:ok, updated_aggregate, events} <- ProductAggregate.execute(aggregate, command),
           {:ok, _} <- ProductRepository.save(updated_aggregate) do
        UnitOfWork.add_events(events)
        Enum.each(events, &EventBus.publish_event/1)
        {:ok, updated_aggregate}
      else
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  def handle(%ReserveStock{} = command) do
    UnitOfWork.transaction_with_events(fn ->
      with {:ok, aggregate} <- ProductRepository.get(command.product_id),
           {:ok, updated_aggregate, events} <- ProductAggregate.execute(aggregate, command),
           {:ok, _} <- ProductRepository.save(updated_aggregate) do
        UnitOfWork.add_events(events)
        Enum.each(events, &EventBus.publish_event/1)
        {:ok, updated_aggregate}
      else
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  def handle(%ReleaseStock{} = command) do
    UnitOfWork.transaction_with_events(fn ->
      with {:ok, aggregate} <- ProductRepository.get(command.product_id),
           {:ok, updated_aggregate, events} <- ProductAggregate.execute(aggregate, command),
           {:ok, _} <- ProductRepository.save(updated_aggregate) do
        UnitOfWork.add_events(events)
        Enum.each(events, &EventBus.publish_event/1)
        {:ok, updated_aggregate}
      else
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  # Private functions

  defp validate_category_change(%UpdateProduct{category_id: category_id})
       when not is_nil(category_id) do
    case CategoryRepository.get(category_id) do
      {:ok, _} -> :ok
      {:error, _} -> {:error, "Category not found"}
    end
  end

  defp validate_category_change(_), do: :ok

  defp check_can_delete(aggregate) do
    if aggregate.stock_quantity > 0 do
      {:error, "Cannot delete product with stock"}
    else
      :ok
    end
  end
end

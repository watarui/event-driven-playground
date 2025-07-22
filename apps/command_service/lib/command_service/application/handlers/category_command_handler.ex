defmodule CommandService.Application.Handlers.CategoryCommandHandler do
  @moduledoc """
  カテゴリコマンドハンドラー

  カテゴリに関するコマンドを処理し、ドメインロジックを実行します。
  """

  alias CommandService.Domain.Aggregates.CategoryAggregate
  alias CommandService.Infrastructure.Repositories.CategoryRepository
  alias CommandService.Infrastructure.UnitOfWork
  alias Shared.Infrastructure.EventBus

  alias CommandService.Application.Commands.CategoryCommands.{
    CreateCategory,
    UpdateCategory,
    DeleteCategory
  }

  require Logger

  @doc """
  カテゴリ作成コマンドを処理する
  """
  def handle(%CreateCategory{} = command) do
    UnitOfWork.transaction_with_events(fn ->
      # 新しいカテゴリアグリゲートを作成
      aggregate = CategoryAggregate.new()

      # コマンドを実行
      case CategoryAggregate.execute(aggregate, command) do
        {:ok, updated_aggregate, events} ->
          # アグリゲートを保存
          case CategoryRepository.save(updated_aggregate) do
            {:ok, _} ->
              # イベントを UnitOfWork に追加
              UnitOfWork.add_events(events)
              # イベントを発行
              Enum.each(events, &EventBus.publish_event/1)
              {:ok, updated_aggregate}

            {:error, reason} ->
              {:error, reason}
          end

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end

  def handle(%UpdateCategory{} = command) do
    UnitOfWork.transaction_with_events(fn ->
      # 既存のカテゴリを取得
      with {:ok, aggregate} <- CategoryRepository.get(command.id),
           # コマンドを実行
           {:ok, updated_aggregate, events} <- CategoryAggregate.execute(aggregate, command),
           # アグリゲートを保存
           {:ok, _} <- CategoryRepository.save(updated_aggregate) do
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

  def handle(%DeleteCategory{} = command) do
    UnitOfWork.transaction_with_events(fn ->
      # 既存のカテゴリを取得
      with {:ok, aggregate} <- CategoryRepository.get(command.id),
           # 削除可能かチェック（子カテゴリや商品がないか）
           :ok <- check_can_delete(command.id),
           # コマンドを実行
           {:ok, updated_aggregate, events} <- CategoryAggregate.execute(aggregate, command),
           # アグリゲートを保存
           {:ok, _} <- CategoryRepository.save(updated_aggregate) do
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

  # Private functions

  defp check_can_delete(category_id) do
    # has_children? は現在の実装では常に {:ok, false} を返すため、
    # 将来の拡張性のために基本的なチェックは残しつつ、警告を回避
    with {:ok, has_children} <- CategoryRepository.has_children?(category_id),
         {:ok, has_products} <- CategoryRepository.has_products?(category_id) do
      cond do
        has_children ->
          {:error, "Cannot delete category with sub-categories"}

        has_products ->
          {:error, "Cannot delete category with products"}

        true ->
          :ok
      end
    else
      error ->
        error
    end
  end
end

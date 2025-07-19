defmodule QueryService.Infrastructure.Projections.CategoryProjection do
  @moduledoc """
  カテゴリプロジェクション

  カテゴリ関連のイベントを処理し、Read Model を更新します
  """

  alias QueryService.Infrastructure.Repositories.CategoryRepository

  alias Shared.Domain.Events.CategoryEvents.{
    CategoryCreated,
    CategoryUpdated,
    CategoryDeleted
  }

  require Logger

  @doc """
  イベントを処理する
  """
  def handle_event(%CategoryCreated{} = event) do
    attrs = %{
      id: event.id.value,
      name: event.name.value,
      description: event.description,
      parent_id: event.parent_id && event.parent_id.value,
      active: true,
      product_count: 0,
      metadata: %{},
      inserted_at: event.created_at,
      updated_at: event.created_at
    }

    case CategoryRepository.create(attrs) do
      {:ok, category} ->
        Logger.info("Category projection created: #{category.id}")
        {:ok, category}

      {:error, reason} ->
        Logger.error("Failed to create category projection: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_event(%CategoryUpdated{} = event) do
    attrs = %{
      name: event.name.value,
      description: event.description,
      updated_at: event.updated_at
    }

    case CategoryRepository.update(event.id.value, attrs) do
      {:ok, category} ->
        Logger.info("Category projection updated: #{category.id}")
        {:ok, category}

      {:error, reason} ->
        Logger.error("Failed to update category projection: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_event(%CategoryDeleted{} = event) do
    case CategoryRepository.delete(event.id.value) do
      {:ok, _} ->
        Logger.info("Category projection deleted: #{event.id.value}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to delete category projection: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_event(_event) do
    # 他のイベントは無視
    :ok
  end

  @doc """
  すべてのカテゴリプロジェクションをクリアする
  """
  def clear_all do
    CategoryRepository.delete_all()
  end
end

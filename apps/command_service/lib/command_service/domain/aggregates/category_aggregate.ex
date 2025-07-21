defmodule CommandService.Domain.Aggregates.CategoryAggregate do
  @moduledoc """
  カテゴリアグリゲート

  カテゴリの作成、更新、削除に関するビジネスロジックを管理します
  """

  use Shared.Domain.Aggregate.Base

  alias Shared.Domain.ValueObjects.{CategoryName, EntityId}
  alias Shared.Domain.Events.CategoryEvents.{CategoryCreated, CategoryDeleted, CategoryUpdated}

  @enforce_keys [:id]
  defstruct [
    :id,
    :name,
    :description,
    :parent_id,
    :active,
    :version,
    :deleted,
    :created_at,
    :updated_at,
    uncommitted_events: []
  ]

  @type t :: %__MODULE__{
          id: EntityId.t(),
          name: CategoryName.t() | nil,
          description: String.t() | nil,
          parent_id: EntityId.t() | nil,
          active: boolean(),
          version: integer(),
          deleted: boolean(),
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          uncommitted_events: list()
        }

  @impl true
  def new do
    %__MODULE__{
      id: EntityId.generate(),
      version: 0,
      active: true,
      deleted: false,
      uncommitted_events: []
    }
  end

  @doc """
  カテゴリを作成する
  """
  @spec create(String.t()) :: {:ok, t()} | {:error, String.t()}
  def create(name) do
    with {:ok, category_name} <- CategoryName.new(name) do
      aggregate = new()

      event =
        CategoryCreated.new(%{
          id: aggregate.id,
          name: category_name,
          created_at: DateTime.utc_now()
        })

      {:ok, apply_and_record_event(aggregate, event)}
    end
  end

  @doc """
  カテゴリ名を更新する
  """
  @spec update_name(t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def update_name(%__MODULE__{deleted: true}, _name) do
    {:error, "Cannot update deleted category"}
  end

  def update_name(%__MODULE__{} = aggregate, name) do
    with {:ok, category_name} <- CategoryName.new(name) do
      if aggregate.name && aggregate.name.value == category_name.value do
        {:error, "Name is the same"}
      else
        event =
          CategoryUpdated.new(%{
            id: aggregate.id,
            name: category_name,
            updated_at: DateTime.utc_now()
          })

        {:ok, apply_and_record_event(aggregate, event)}
      end
    end
  end

  @doc """
  カテゴリを削除する
  """
  @spec delete(t()) :: {:ok, t()} | {:error, String.t()}
  def delete(%__MODULE__{deleted: true}) do
    {:error, "Category already deleted"}
  end

  def delete(%__MODULE__{} = aggregate) do
    event =
      CategoryDeleted.new(%{
        id: aggregate.id,
        deleted_at: DateTime.utc_now()
      })

    {:ok, apply_and_record_event(aggregate, event)}
  end

  @doc """
  コマンドを実行する
  """
  def execute(
        aggregate,
        %CommandService.Application.Commands.CategoryCommands.CreateCategory{} = command
      ) do
    if aggregate.created_at do
      {:error, "Category already created"}
    else
      event =
        CategoryCreated.new(%{
          id: aggregate.id,
          name: CategoryName.new!(command.name),
          description: command.description,
          parent_id: command.parent_id,
          created_at: DateTime.utc_now()
        })

      updated_aggregate = apply_and_record_event(aggregate, event)
      {:ok, updated_aggregate, [event]}
    end
  end

  def execute(
        aggregate,
        %CommandService.Application.Commands.CategoryCommands.UpdateCategory{} = command
      ) do
    if aggregate.deleted do
      {:error, "Cannot update deleted category"}
    else
      event =
        CategoryUpdated.new(%{
          id: aggregate.id,
          name: command.name && CategoryName.new!(command.name),
          description: command.description,
          parent_id: command.parent_id,
          updated_at: DateTime.utc_now()
        })

      updated_aggregate = apply_and_record_event(aggregate, event)
      {:ok, updated_aggregate, [event]}
    end
  end

  def execute(aggregate, %CommandService.Application.Commands.CategoryCommands.DeleteCategory{}) do
    if aggregate.deleted do
      {:error, "Category already deleted"}
    else
      event =
        CategoryDeleted.new(%{
          id: aggregate.id,
          deleted_at: DateTime.utc_now()
        })

      updated_aggregate = apply_and_record_event(aggregate, event)
      {:ok, updated_aggregate, [event]}
    end
  end

  @impl true
  def apply_event(aggregate, %CategoryCreated{} = event) do
    %{
      aggregate
      | id: event.id,
        name: event.name,
        description: Map.get(event, :description),
        parent_id: Map.get(event, :parent_id),
        created_at: event.created_at,
        updated_at: event.created_at
    }
  end

  def apply_event(aggregate, %CategoryUpdated{} = event) do
    updates = %{
      updated_at: event.updated_at
    }

    updates =
      if Map.has_key?(event, :name) && event.name,
        do: Map.put(updates, :name, event.name),
        else: updates

    updates =
      if Map.has_key?(event, :description),
        do: Map.put(updates, :description, event.description),
        else: updates

    updates =
      if Map.has_key?(event, :parent_id),
        do: Map.put(updates, :parent_id, event.parent_id),
        else: updates

    Map.merge(aggregate, updates)
  end

  def apply_event(aggregate, %CategoryDeleted{} = _event) do
    %{aggregate | deleted: true, updated_at: DateTime.utc_now()}
  end
end

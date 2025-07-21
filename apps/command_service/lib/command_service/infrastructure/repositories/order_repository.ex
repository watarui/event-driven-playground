defmodule CommandService.Infrastructure.Repositories.OrderRepository do
  @moduledoc """
  注文リポジトリの実装
  """

  @behaviour Shared.Domain.Repository

  alias CommandService.Domain.Aggregates.OrderAggregate
  alias Shared.Domain.ValueObjects.EntityId
  alias Shared.Infrastructure.EventStore.EventStore

  # アグリゲートタイプ名
  @aggregate_type "Order"

  @impl true
  def find_by_id(id) do
    case EntityId.from_string(id) do
      {:ok, entity_id} ->
        stream_name = "#{@aggregate_type}-#{entity_id.value}"

        case EventStore.get_events(stream_name) do
          {:ok, events} when events != [] ->
            aggregate = rebuild_aggregate_from_events(events)
            {:ok, aggregate}

          {:ok, []} ->
            {:error, :not_found}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def save(aggregate) do
    # 新しいアグリゲートの場合、バージョンは0から始まる
    # uncommitted_eventsが適用される前のバージョンを使用
    expected_version = aggregate.version - length(aggregate.uncommitted_events)

    case EventStore.append_events(
           aggregate.id.value,
           @aggregate_type,
           aggregate.uncommitted_events,
           expected_version,
           %{}
         ) do
      {:ok, _} ->
        # uncommitted_events をクリア
        updated_aggregate = %{
          aggregate
          | uncommitted_events: []
        }

        {:ok, updated_aggregate}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def aggregate_type, do: :order

  @impl true
  def delete(_id) do
    # イベントソーシングでは論理削除を使用
    {:error, "Delete not supported for event-sourced aggregates"}
  end

  @impl true
  def find_by_ids(ids) when is_list(ids) do
    results =
      ids
      |> Enum.map(&find_by_id/1)
      |> Enum.reduce({[], []}, fn
        {:ok, aggregate}, {aggregates, errors} ->
          {[aggregate | aggregates], errors}

        {:error, error}, {aggregates, errors} ->
          {aggregates, [error | errors]}
      end)

    case results do
      {aggregates, []} -> {:ok, Enum.reverse(aggregates)}
      {_, errors} -> {:error, {:partial_failure, errors}}
    end
  end

  @impl true
  def find_by(_criteria) do
    {:error, :not_supported}
  end

  @impl true
  def all(_opts \\ []) do
    {:error, :not_supported}
  end

  @impl true
  def count(_opts \\ []) do
    {:error, :not_supported}
  end

  @impl true
  def exists?(id) do
    case find_by_id(id) do
      {:ok, _} -> true
      _ -> false
    end
  end

  @impl true
  def transaction(fun) do
    # EventStore already handles transactions
    try do
      {:ok, fun.()}
    rescue
      e -> {:error, e}
    end
  end

  # Private functions

  defp rebuild_aggregate_from_events(events) do
    Enum.reduce(events, OrderAggregate.new(), fn event, aggregate ->
      OrderAggregate.apply_event(aggregate, event)
    end)
  end
end

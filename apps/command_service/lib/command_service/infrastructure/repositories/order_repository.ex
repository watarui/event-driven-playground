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
  def delete(id) do
    # イベントソーシングでは論理削除を使用
    {:error, "Delete not supported for event-sourced aggregates"}
  end

  # Private functions

  defp rebuild_aggregate_from_events(events) do
    Enum.reduce(events, OrderAggregate.new(), fn event, aggregate ->
      OrderAggregate.apply_event(aggregate, event)
    end)
  end
end

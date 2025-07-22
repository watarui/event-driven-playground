defmodule CommandService.Infrastructure.Firestore.ProductRepository do
  @moduledoc """
  商品リポジトリの Firestore 実装
  """

  @behaviour Shared.Domain.Repository

  alias CommandService.Domain.Aggregates.ProductAggregate
  alias Shared.Domain.ValueObjects.EntityId
  alias Shared.Infrastructure.Firestore.EventStoreRepository

  # アグリゲートタイプ名
  @aggregate_type "Product"

  @impl true
  def find_by_id(id) do
    case EntityId.from_string(id) do
      {:ok, entity_id} ->
        aggregate_id = "#{@aggregate_type}:#{entity_id.value}"

        case EventStoreRepository.get_events(aggregate_id) do
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
    aggregate_id = "#{@aggregate_type}:#{aggregate.id.value}"

    case EventStoreRepository.append_events(aggregate_id, aggregate.uncommitted_events) do
      {:ok, _version} ->
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
  def aggregate_type, do: :product

  @impl true
  def delete(_id) do
    {:error, :not_allowed}
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
    try do
      {:ok, fun.()}
    rescue
      e -> {:error, e}
    end
  end

  # Private functions

  defp rebuild_aggregate_from_events(events) do
    Enum.reduce(events, ProductAggregate.new(), fn event, aggregate ->
      ProductAggregate.apply_event(aggregate, event)
    end)
  end
end

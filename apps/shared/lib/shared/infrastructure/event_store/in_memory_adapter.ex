defmodule Shared.Infrastructure.EventStore.InMemoryAdapter do
  @moduledoc """
  インメモリのイベントストア実装（開発・テスト用）
  """

  @behaviour Shared.Infrastructure.EventStore.EventStore

  use GenServer

  alias Shared.Config

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Shared.Infrastructure.EventStore.EventStore
  def append_events(aggregate_id, aggregate_type, events, expected_version, metadata) do
    GenServer.call(
      __MODULE__,
      {:append_events, aggregate_id, aggregate_type, events, expected_version, metadata}
    )
  end

  @impl Shared.Infrastructure.EventStore.EventStore
  def get_events(aggregate_id, from_version) do
    GenServer.call(__MODULE__, {:get_events, aggregate_id, from_version})
  end

  @impl Shared.Infrastructure.EventStore.EventStore
  def get_events_by_type(event_type, opts) do
    GenServer.call(__MODULE__, {:get_events_by_type, event_type, opts})
  end

  @impl Shared.Infrastructure.EventStore.EventStore
  def subscribe(subscriber, opts) do
    GenServer.call(__MODULE__, {:subscribe, subscriber, opts})
  end

  @impl Shared.Infrastructure.EventStore.EventStore
  def unsubscribe(subscription) do
    GenServer.call(__MODULE__, {:unsubscribe, subscription})
  end

  # Server callbacks

  @impl GenServer
  def init(_opts) do
    event_bus = Config.event_bus_module()
    {:ok, %{events: [], id_counter: 0, event_bus: event_bus}}
  end

  @impl GenServer
  def handle_call(
        {:append_events, aggregate_id, aggregate_type, events, expected_version, metadata},
        _from,
        state
      ) do
    current_version = get_aggregate_version(state.events, aggregate_id)

    if current_version == expected_version do
      {new_events, new_state} =
        events
        |> Enum.with_index(1)
        |> Enum.reduce({[], state}, fn {event, index}, {acc_events, acc_state} ->
          event_record = %{
            id: acc_state.id_counter + 1,
            aggregate_id: aggregate_id,
            aggregate_type: aggregate_type,
            event_type: event.__struct__.event_type(),
            event_data: event,
            event_version: expected_version + index,
            metadata: metadata,
            inserted_at: DateTime.utc_now()
          }

          {acc_events ++ [event_record], %{acc_state | id_counter: acc_state.id_counter + 1}}
        end)

      # イベントバスに発行
      Enum.each(new_events, fn event_record ->
        state.event_bus.publish(String.to_atom(event_record.event_type), event_record.event_data)
      end)

      final_version = expected_version + length(events)
      updated_state = %{new_state | events: state.events ++ new_events}

      {:reply, {:ok, final_version}, updated_state}
    else
      {:reply, {:error, :version_mismatch}, state}
    end
  end

  @impl GenServer
  def handle_call({:get_events, aggregate_id, from_version}, _from, state) do
    events =
      state.events
      |> Enum.filter(fn e ->
        e.aggregate_id == aggregate_id and
          (is_nil(from_version) or e.event_version > from_version)
      end)
      |> Enum.sort_by(& &1.event_version)
      |> Enum.map(& &1.event_data)

    {:reply, {:ok, events}, state}
  end

  @impl GenServer
  def handle_call({:get_events_by_type, event_type, opts}, _from, state) do
    limit = Keyword.get(opts, :limit, 100)
    after_id = Keyword.get(opts, :after_id)

    events =
      state.events
      |> Enum.filter(fn e ->
        e.event_type == event_type and
          (is_nil(after_id) or e.id > after_id)
      end)
      |> Enum.sort_by(& &1.id)
      |> Enum.take(limit)
      |> Enum.map(& &1.event_data)

    {:reply, {:ok, events}, state}
  end

  @impl GenServer
  def handle_call({:subscribe, subscriber, opts}, _from, state) do
    event_types = Keyword.get(opts, :event_types, :all)

    if event_types == :all do
      state.event_bus.subscribe_all()
    else
      Enum.each(event_types, &state.event_bus.subscribe/1)
    end

    {:reply, {:ok, {subscriber, event_types}}, state}
  end

  @impl GenServer
  def handle_call({:unsubscribe, {_subscriber, event_types}}, _from, state) do
    if event_types == :all do
      state.event_bus.unsubscribe_all()
    else
      Enum.each(event_types, &state.event_bus.unsubscribe/1)
    end

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:get_events_after, after_id, limit}, _from, state) do
    events =
      state.events
      |> Enum.sort_by(& &1.id)
      |> Enum.filter(&(&1.id > after_id))
      |> Enum.take(limit || 100)
      |> Enum.map(& &1.event_data)

    {:reply, events, state}
  end

  @impl GenServer
  def handle_call(
        {:save_snapshot, aggregate_id, _aggregate_type, version, data, metadata},
        _from,
        state
      ) do
    snapshot = %{
      aggregate_id: aggregate_id,
      version: version,
      data: data,
      metadata: metadata,
      created_at: DateTime.utc_now()
    }

    snapshots = Map.put(Map.get(state, :snapshots, %{}), aggregate_id, snapshot)
    {:reply, {:ok, snapshot}, Map.put(state, :snapshots, snapshots)}
  end

  @impl GenServer
  def handle_call({:get_snapshot, aggregate_id}, _from, state) do
    snapshots = Map.get(state, :snapshots, %{})

    case Map.get(snapshots, aggregate_id) do
      nil -> {:reply, {:error, :not_found}, state}
      snapshot -> {:reply, {:ok, snapshot}, state}
    end
  end

  @impl true
  def get_events_after(after_id, limit) do
    state = GenServer.call(__MODULE__, {:get_events_after, after_id, limit})
    {:ok, state}
  end

  @impl true
  def save_snapshot(aggregate_id, aggregate_type, version, data, metadata) do
    GenServer.call(
      __MODULE__,
      {:save_snapshot, aggregate_id, aggregate_type, version, data, metadata}
    )
  end

  @impl true
  def get_snapshot(aggregate_id) do
    GenServer.call(__MODULE__, {:get_snapshot, aggregate_id})
  end

  # Private functions

  defp get_aggregate_version(events, aggregate_id) do
    events
    |> Enum.filter(fn e -> e.aggregate_id == aggregate_id end)
    |> Enum.map(& &1.event_version)
    |> Enum.max(fn -> 0 end)
  end
end

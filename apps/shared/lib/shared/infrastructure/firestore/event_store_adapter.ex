defmodule Shared.Infrastructure.Firestore.EventStoreAdapter do
  @moduledoc """
  Firestore を使用したイベントストアアダプター
  
  EventStore のビヘイビアを実装し、Firestore EventStoreRepository に委譲します。
  """

  @behaviour Shared.Infrastructure.EventStore.EventStore

  alias Shared.Infrastructure.Firestore.EventStoreRepository

  @impl true
  def append_events(aggregate_id, aggregate_type, events, expected_version, metadata) do
    # aggregate_id を構築
    full_aggregate_id = "#{aggregate_type}:#{aggregate_id}"
    
    # イベントにメタデータを追加
    events_with_metadata = 
      events
      |> Enum.with_index(expected_version + 1)
      |> Enum.map(fn {event, version} ->
        %{event | 
          version: version,
          metadata: Map.merge(event.metadata || %{}, metadata)
        }
      end)
    
    EventStoreRepository.append_events(full_aggregate_id, events_with_metadata)
  end

  @impl true
  def get_events(aggregate_id, from_version) do
    # aggregate_id からタイプとIDを分離（既に結合されている場合）
    full_aggregate_id = 
      if String.contains?(aggregate_id, ":") do
        aggregate_id
      else
        # タイプが不明な場合は、全タイプから検索（非効率だが互換性のため）
        "Order:#{aggregate_id}"
      end
    
    EventStoreRepository.get_events(full_aggregate_id, from_version: from_version)
  end

  @impl true
  def get_events_by_type(_event_type, _opts) do
    # TODO: 実装が必要
    {:ok, []}
  end

  @impl true
  def subscribe(_subscriber, _opts) do
    # Firestore はリアルタイムサブスクリプションをサポートしていない（このパターンでは）
    {:error, :not_supported}
  end

  @impl true
  def unsubscribe(_subscription) do
    {:error, :not_supported}
  end

  @impl true
  def get_events_after(_after_id, _limit) do
    # TODO: 実装が必要
    {:ok, []}
  end

  @impl true
  def save_snapshot(aggregate_id, aggregate_type, version, data, metadata) do
    full_aggregate_id = "#{aggregate_type}:#{aggregate_id}"
    snapshot = Map.merge(data, metadata)
    
    case EventStoreRepository.save_snapshot(full_aggregate_id, snapshot, version) do
      :ok -> {:ok, snapshot}
      error -> error
    end
  end

  @impl true
  def get_snapshot(aggregate_id) do
    # aggregate_id からタイプとIDを分離（既に結合されている場合）
    full_aggregate_id = 
      if String.contains?(aggregate_id, ":") do
        aggregate_id
      else
        "Order:#{aggregate_id}"
      end
    
    case EventStoreRepository.get_latest_snapshot(full_aggregate_id) do
      {:ok, {snapshot, _version}} -> {:ok, snapshot}
      error -> error
    end
  end
end
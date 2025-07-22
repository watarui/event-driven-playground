defmodule Shared.Infrastructure.Firestore.EventStoreAdapter do
  @moduledoc """
  Firestore を使用したイベントストアアダプター

  EventStore のビヘイビアを実装し、Firestore EventStoreRepository に委譲します。
  """

  @behaviour Shared.Behaviours.EventStore

  alias Shared.Infrastructure.Firestore.EventStoreRepository

  @impl true
  def append_events(stream_id, events, expected_version, metadata \\ %{}) do
    # イベントにメタデータとバージョンを追加
    events_with_metadata =
      events
      |> Enum.with_index(expected_version + 1)
      |> Enum.map(fn {event, version} ->
        Map.merge(event, %{
          version: version,
          metadata: Map.merge(Map.get(event, :metadata, %{}), metadata)
        })
      end)

    case EventStoreRepository.append_events(stream_id, events_with_metadata) do
      {:ok, _} -> {:ok, expected_version + length(events)}
      error -> error
    end
  end

  @impl true
  def read_stream(stream_id, from_version \\ 0) do
    EventStoreRepository.get_events(stream_id, from_version: from_version)
  end

  @impl true
  def read_all_events(_limit \\ 100) do
    # TODO: 全イベントの読み取り実装
    {:ok, []}
  end

  @impl true
  def subscribe(_stream_id_or_all, _pid) do
    # Firestore はリアルタイムサブスクリプションをサポートしていない（このパターンでは）
    {:error, :not_supported}
  end

  @impl true
  def unsubscribe(_subscription) do
    {:error, :not_supported}
  end

  @impl true
  def archive_events(_days) do
    # TODO: アーカイブ実装
    {:ok, 0}
  end

  @impl true
  def get_stream_version(stream_id) do
    case EventStoreRepository.get_events_after_version(stream_id, -1) do
      {:ok, events} -> {:ok, length(events)}
      {:error, :not_found} -> {:ok, 0}
      error -> error
    end
  end

  @impl true
  def health_check do
    # Firestore の接続確認
    case EventStoreRepository.get_events("health_check_stream", from_version: 0) do
      {:ok, _} -> :ok
      # ストリームが存在しなくても接続は確認できた
      {:error, :not_found} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # 以下は EventStore ビヘイビアに含まれていない追加メソッド（後方互換性のため）
  def append_events(aggregate_id, aggregate_type, events, expected_version, metadata) do
    # aggregate_id を構築
    full_aggregate_id = "#{aggregate_type}:#{aggregate_id}"
    append_events(full_aggregate_id, events, expected_version, metadata)
  end

  def get_events(aggregate_id, from_version) do
    read_stream(aggregate_id, from_version)
  end

  def get_events_by_type(_event_type, _opts) do
    # TODO: イベントタイプでのフィルタリング実装
    {:ok, []}
  end

  def get_events_after(_after_id, _limit) do
    # TODO: イベントIDによる読み取り実装
    {:ok, []}
  end

  def save_snapshot(aggregate_id, aggregate_type, version, data, metadata) do
    full_aggregate_id = "#{aggregate_type}:#{aggregate_id}"
    snapshot = Map.merge(data, metadata)

    case EventStoreRepository.save_snapshot(full_aggregate_id, snapshot, version) do
      :ok -> {:ok, snapshot}
      error -> error
    end
  end

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

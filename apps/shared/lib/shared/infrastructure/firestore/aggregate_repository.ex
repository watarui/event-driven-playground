defmodule Shared.Infrastructure.Firestore.AggregateRepository do
  @moduledoc """
  Firestore を使用したアグリゲートリポジトリの実装

  イベントソーシングとスナップショットをサポートします。
  """

  require Logger
  alias Shared.Infrastructure.Firestore.EventStore

  @doc """
  アグリゲートを保存する
  """
  @spec save(module(), struct(), integer()) :: {:ok, struct()} | {:error, term()}
  def save(aggregate_module, aggregate, expected_version) do
    events = aggregate_module.get_uncommitted_events(aggregate)
    
    if Enum.empty?(events) do
      {:ok, aggregate}
    else
      aggregate_id = aggregate_module.get_id(aggregate)
      aggregate_type = to_string(aggregate_module)

      case EventStore.save_events(aggregate_id, aggregate_type, events, expected_version) do
        {:ok, _events} ->
          # イベントをコミット済みとしてマーク
          updated_aggregate = aggregate_module.mark_events_as_committed(aggregate)
          
          # スナップショットの作成を検討
          maybe_create_snapshot(aggregate_module, updated_aggregate, expected_version + length(events))
          
          {:ok, updated_aggregate}
        
        {:error, :concurrent_modification} = error ->
          Logger.warning("Concurrent modification detected for aggregate #{aggregate_id}")
          error
        
        error ->
          Logger.error("Failed to save aggregate: #{inspect(error)}")
          error
      end
    end
  end

  @doc """
  アグリゲートをIDで取得する
  """
  @spec get(module(), String.t()) :: {:ok, struct()} | {:error, :not_found}
  def get(aggregate_module, aggregate_id) do
    # スナップショットを取得
    case EventStore.get_latest_snapshot(aggregate_id) do
      {:ok, nil} ->
        # スナップショットがない場合は全イベントから再構築
        load_from_events(aggregate_module, aggregate_id, 0)
      
      {:ok, snapshot} ->
        # スナップショットから開始
        case load_from_snapshot(aggregate_module, snapshot) do
          {:ok, aggregate, version} ->
            # スナップショット以降のイベントを適用
            load_from_events_with_base(aggregate_module, aggregate_id, aggregate, version)
          
          error ->
            Logger.warning("Failed to load from snapshot, falling back to events: #{inspect(error)}")
            load_from_events(aggregate_module, aggregate_id, 0)
        end
      
      error ->
        Logger.error("Failed to get snapshot: #{inspect(error)}")
        {:error, :repository_error}
    end
  end

  @doc """
  アグリゲートの現在のバージョンを取得する
  """
  @spec get_version(module(), String.t()) :: {:ok, integer()} | {:error, :not_found}
  def get_version(aggregate_module, aggregate_id) do
    case get(aggregate_module, aggregate_id) do
      {:ok, aggregate} -> 
        {:ok, aggregate_module.get_version(aggregate)}
      
      error -> 
        error
    end
  end

  # Private functions

  defp load_from_events(aggregate_module, aggregate_id, after_version) do
    case EventStore.get_events(aggregate_id, after_version) do
      {:ok, []} ->
        {:error, :not_found}
      
      {:ok, events} ->
        # 新しいアグリゲートを作成してイベントを適用
        aggregate = aggregate_module.new()
        aggregate = apply_events(aggregate_module, aggregate, events)
        {:ok, aggregate}
      
      error ->
        Logger.error("Failed to load events: #{inspect(error)}")
        {:error, :repository_error}
    end
  end

  defp load_from_events_with_base(aggregate_module, aggregate_id, base_aggregate, after_version) do
    case EventStore.get_events(aggregate_id, after_version) do
      {:ok, events} ->
        # 既存のアグリゲートにイベントを適用
        aggregate = apply_events(aggregate_module, base_aggregate, events)
        {:ok, aggregate}
      
      error ->
        Logger.error("Failed to load events: #{inspect(error)}")
        {:error, :repository_error}
    end
  end

  defp load_from_snapshot(aggregate_module, snapshot) do
    try do
      # スナップショットからアグリゲートを復元
      aggregate = aggregate_module.from_snapshot(snapshot.snapshot_data)
      {:ok, aggregate, snapshot.version}
    rescue
      e ->
        Logger.error("Failed to restore from snapshot: #{inspect(e)}")
        {:error, :invalid_snapshot}
    end
  end

  defp apply_events(aggregate_module, aggregate, events) do
    Enum.reduce(events, aggregate, fn event_data, acc ->
      # イベントデータからイベント構造体を復元
      event = restore_event(event_data)
      aggregate_module.apply_event(acc, event)
    end)
  end

  defp restore_event(event_data) do
    # イベントタイプからモジュールを特定
    event_module = String.to_existing_atom(event_data.event_type)
    
    # イベントデータから構造体を作成
    struct(event_module, event_data.event_data)
  rescue
    _ ->
      # フォールバック: マップとして返す
      Map.put(event_data.event_data, :__struct__, event_data.event_type)
  end

  defp maybe_create_snapshot(aggregate_module, aggregate, version) do
    # スナップショット作成の閾値（例: 10イベントごと）
    snapshot_frequency = Application.get_env(:shared, :snapshot_frequency, 10)
    
    if rem(version, snapshot_frequency) == 0 do
      Task.start(fn ->
        create_snapshot(aggregate_module, aggregate, version)
      end)
    end
  end

  defp create_snapshot(aggregate_module, aggregate, version) do
    aggregate_id = aggregate_module.get_id(aggregate)
    aggregate_type = to_string(aggregate_module)
    
    # アグリゲートをスナップショット用にシリアライズ
    snapshot_data = aggregate_module.to_snapshot(aggregate)
    
    case EventStore.save_snapshot(aggregate_id, aggregate_type, snapshot_data, version) do
      :ok ->
        Logger.info("Snapshot created for aggregate #{aggregate_id} at version #{version}")
      
      {:error, reason} ->
        Logger.warning("Failed to create snapshot: #{inspect(reason)}")
    end
  end
end
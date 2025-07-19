defmodule Shared.Infrastructure.EventStore.AggregateStore do
  @moduledoc """
  アグリゲートのイベントソーシングとスナップショット機能を統合したストア

  スナップショットを活用してパフォーマンスを最適化しながら、
  イベントソーシングパターンを実装する
  """

  alias Shared.Infrastructure.EventStore.EventStore
  alias Shared.Infrastructure.EventStore.SnapshotStore
  require Logger

  # スナップショットを作成するイベント数の閾値
  @snapshot_frequency 10

  @doc """
  アグリゲートを保存する（イベントの永続化とスナップショットの作成）
  """
  def save(
        aggregate_module,
        aggregate_id,
        aggregate_type,
        events,
        expected_version,
        metadata \\ %{}
      ) do
    case EventStore.append_events(
           aggregate_id,
           aggregate_type,
           events,
           expected_version,
           metadata
         ) do
      {:ok, new_version} ->
        # スナップショットの作成を検討
        maybe_create_snapshot(aggregate_module, aggregate_id, aggregate_type, new_version)
        {:ok, new_version}

      error ->
        error
    end
  end

  @doc """
  アグリゲートを読み込む（スナップショットとイベントから再構築）
  """
  def load(aggregate_module, aggregate_id) do
    # スナップショットを取得
    snapshot_result = EventStore.get_snapshot(aggregate_id)

    case snapshot_result do
      {:ok, snapshot} ->
        # スナップショット以降のイベントを取得
        case EventStore.get_events(aggregate_id, snapshot.version) do
          {:ok, events} ->
            # スナップショットとイベントから再構築
            aggregate =
              aggregate_module.rebuild_from_snapshot_and_events(
                snapshot.data,
                events
              )

            {:ok, aggregate}

          error ->
            Logger.warning("Failed to get events after snapshot: #{inspect(error)}")
            # スナップショットが使えない場合は全イベントから再構築
            load_from_events(aggregate_module, aggregate_id)
        end

      {:error, :not_found} ->
        # スナップショットがない場合は全イベントから再構築
        load_from_events(aggregate_module, aggregate_id)

      error ->
        Logger.error("Failed to get snapshot: #{inspect(error)}")
        load_from_events(aggregate_module, aggregate_id)
    end
  end

  @doc """
  アグリゲートのバージョンを取得する
  """
  def get_version(aggregate_id) do
    # まずスナップショットから取得を試みる
    case EventStore.get_snapshot(aggregate_id) do
      {:ok, snapshot} ->
        # スナップショット以降のイベント数を確認
        case EventStore.get_events(aggregate_id, snapshot.version) do
          {:ok, events} ->
            {:ok, snapshot.version + length(events)}

          _ ->
            # エラーの場合は全イベントから計算
            get_version_from_events(aggregate_id)
        end

      {:error, :not_found} ->
        get_version_from_events(aggregate_id)
    end
  end

  @doc """
  スナップショットを手動で作成する
  """
  def create_snapshot(aggregate_module, aggregate_id, aggregate_type) do
    case load_from_events(aggregate_module, aggregate_id) do
      {:ok, aggregate} ->
        version = aggregate_module.get_version(aggregate)
        data = aggregate_module.to_snapshot(aggregate)

        case EventStore.save_snapshot(aggregate_id, aggregate_type, version, data) do
          {:ok, _} ->
            Logger.info("Snapshot created for aggregate #{aggregate_id} at version #{version}")
            # 古いスナップショットを削除
            SnapshotStore.prune_old_snapshots(aggregate_id, 3)
            :ok

          error ->
            Logger.error("Failed to create snapshot: #{inspect(error)}")
            error
        end

      error ->
        error
    end
  end

  # プライベート関数

  defp load_from_events(aggregate_module, aggregate_id) do
    case EventStore.get_events(aggregate_id) do
      {:ok, events} ->
        aggregate = aggregate_module.rebuild_from_events(events)
        {:ok, aggregate}

      error ->
        error
    end
  end

  defp get_version_from_events(aggregate_id) do
    case EventStore.get_events(aggregate_id) do
      {:ok, events} ->
        {:ok, length(events)}

      error ->
        error
    end
  end

  defp maybe_create_snapshot(aggregate_module, aggregate_id, aggregate_type, version) do
    # スナップショット作成頻度をチェック
    if rem(version, @snapshot_frequency) == 0 do
      # 非同期でスナップショットを作成
      Task.start(fn ->
        create_snapshot(aggregate_module, aggregate_id, aggregate_type)
      end)
    end
  end
end

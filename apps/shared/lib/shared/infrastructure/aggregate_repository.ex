defmodule Shared.Infrastructure.AggregateRepository do
  @moduledoc """
  アグリゲートの永続化と再構築を行うリポジトリ

  楽観的ロックとバージョン管理を提供します
  """

  alias Shared.Infrastructure.EventStore.EventStore
  alias Shared.Infrastructure.EventStore.VersionConflictError
  require Logger

  @doc """
  アグリゲートを保存する

  新規作成または既存アグリゲートの更新を行います。
  楽観的ロックにより、同時更新を防ぎます。
  """
  def save(aggregate_module, aggregate_id, events, expected_version \\ 0, metadata \\ %{}) do
    aggregate_type = aggregate_module.aggregate_type()

    case EventStore.append_events(
           aggregate_id,
           aggregate_type,
           events,
           expected_version,
           metadata
         ) do
      {:ok, new_version} ->
        {:ok, new_version}

      {:error, %VersionConflictError{} = error} ->
        Logger.warning(
          "Version conflict for aggregate #{aggregate_id}: #{Exception.message(error)}"
        )

        {:error, error}

      {:error, reason} ->
        Logger.error("Failed to save aggregate #{aggregate_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  アグリゲートを読み込む

  イベントストアからイベントを取得し、アグリゲートを再構築します。
  スナップショットがある場合は、それを起点として使用します。
  """
  def load(aggregate_module, aggregate_id) do
    # スナップショットを取得
    {snapshot_version, initial_state} =
      case EventStore.get_snapshot(aggregate_id) do
        {:ok, snapshot} ->
          {snapshot.version, restore_aggregate_state(aggregate_module, snapshot.data)}

        {:error, :not_found} ->
          {0, aggregate_module.new(aggregate_id)}
      end

    # スナップショット以降のイベントを取得
    case EventStore.get_events(aggregate_id, snapshot_version) do
      {:ok, events} ->
        # イベントを適用してアグリゲートを再構築
        aggregate =
          Enum.reduce(events, initial_state, fn event, acc ->
            aggregate_module.apply_event(acc, event)
          end)

        {:ok, aggregate}

      {:error, reason} ->
        Logger.error("Failed to load aggregate #{aggregate_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  アグリゲートの現在のバージョンを取得する
  """
  def get_version(aggregate_id) do
    case EventStore.get_events(aggregate_id) do
      {:ok, events} ->
        {:ok, length(events)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  アグリゲートのスナップショットを作成する
  """
  def create_snapshot(aggregate_module, aggregate_id) do
    case load(aggregate_module, aggregate_id) do
      {:ok, aggregate} ->
        version = get_aggregate_version(aggregate)
        data = aggregate_to_snapshot_data(aggregate)
        metadata = %{created_at: DateTime.utc_now()}

        EventStore.save_snapshot(
          aggregate_id,
          aggregate_module.aggregate_type(),
          version,
          data,
          metadata
        )

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private functions

  defp restore_aggregate_state(aggregate_module, snapshot_data) do
    # スナップショットデータからアグリゲートを復元
    struct(aggregate_module, snapshot_data)
  end

  defp aggregate_to_snapshot_data(aggregate) do
    # アグリゲートをスナップショット用のデータに変換
    aggregate
    |> Map.from_struct()
    |> Map.drop([:__meta__])
  end

  defp get_aggregate_version(aggregate) do
    Map.get(aggregate, :version, 0)
  end
end

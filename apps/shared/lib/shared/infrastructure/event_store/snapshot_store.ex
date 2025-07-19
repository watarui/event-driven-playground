defmodule Shared.Infrastructure.EventStore.SnapshotStore do
  @moduledoc """
  スナップショットの保存と取得を管理するモジュール
  """

  alias Shared.Infrastructure.EventStore.Repo
  alias Shared.Infrastructure.EventStore.Snapshot
  import Ecto.Query

  @doc """
  スナップショットを保存する
  """
  def save_snapshot(aggregate_id, aggregate_type, version, data, metadata \\ %{}) do
    attrs = %{
      aggregate_id: aggregate_id,
      aggregate_type: aggregate_type,
      version: version,
      data: serialize_aggregate_data(data),
      metadata: metadata
    }

    %Snapshot{}
    |> Snapshot.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  指定されたアグリゲートの最新のスナップショットを取得する
  """
  def get_latest_snapshot(aggregate_id) do
    query =
      from(s in Snapshot,
        where: s.aggregate_id == ^aggregate_id,
        order_by: [desc: s.version],
        limit: 1
      )

    case Repo.one(query) do
      nil -> {:error, :not_found}
      snapshot -> {:ok, deserialize_snapshot(snapshot)}
    end
  end

  @doc """
  指定されたバージョン以前の最新のスナップショットを取得する
  """
  def get_snapshot_before_version(aggregate_id, version) do
    query =
      from(s in Snapshot,
        where: s.aggregate_id == ^aggregate_id and s.version < ^version,
        order_by: [desc: s.version],
        limit: 1
      )

    case Repo.one(query) do
      nil -> {:error, :not_found}
      snapshot -> {:ok, deserialize_snapshot(snapshot)}
    end
  end

  @doc """
  古いスナップショットを削除する（最新のN個を残す）
  """
  def prune_old_snapshots(aggregate_id, keep_count \\ 3) do
    # 保持するスナップショットのバージョンを取得
    keep_versions =
      from(s in Snapshot,
        where: s.aggregate_id == ^aggregate_id,
        order_by: [desc: s.version],
        limit: ^keep_count,
        select: s.version
      )

    versions_to_keep = Repo.all(keep_versions)

    # それ以外を削除
    delete_query =
      from(s in Snapshot,
        where: s.aggregate_id == ^aggregate_id and s.version not in ^versions_to_keep
      )

    Repo.delete_all(delete_query)
  end

  @doc """
  指定された期間より古いスナップショットを削除する
  """
  def prune_snapshots_older_than(days) do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)

    delete_query =
      from(s in Snapshot,
        where: s.inserted_at < ^cutoff_date
      )

    Repo.delete_all(delete_query)
  end

  # プライベート関数

  defp serialize_aggregate_data(data) do
    # アグリゲートデータをマップ形式にシリアライズ
    # 値オブジェクトも含めて適切にシリアライズする
    data
    |> Map.from_struct()
    |> serialize_value_objects()
  end

  defp serialize_value_objects(data) when is_map(data) do
    data
    |> Enum.map(fn {key, value} -> {key, serialize_value(value)} end)
    |> Enum.into(%{})
  end

  defp serialize_value(%{__struct__: module} = struct) do
    # 値オブジェクトの場合は、to_primitives関数を使用
    if function_exported?(module, :to_primitives, 1) do
      module.to_primitives(struct)
    else
      # 通常の構造体の場合
      struct
      |> Map.from_struct()
      |> Map.put(:__type__, to_string(module))
      |> serialize_value_objects()
    end
  end

  defp serialize_value(value) when is_list(value) do
    Enum.map(value, &serialize_value/1)
  end

  defp serialize_value(value), do: value

  defp deserialize_snapshot(snapshot) do
    %{
      aggregate_id: snapshot.aggregate_id,
      aggregate_type: snapshot.aggregate_type,
      version: snapshot.version,
      data: snapshot.data,
      metadata: snapshot.metadata,
      created_at: snapshot.inserted_at
    }
  end
end

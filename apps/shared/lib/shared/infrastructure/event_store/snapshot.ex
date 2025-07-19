defmodule Shared.Infrastructure.EventStore.Snapshot do
  @moduledoc """
  スナップショットのスキーマ定義

  アグリゲートの特定時点の状態を保存し、
  イベント再生時のパフォーマンスを向上させる
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Shared.SchemaHelpers

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]
  event_store_schema()

  schema "snapshots" do
    field(:aggregate_id, :string)
    field(:aggregate_type, :string)
    field(:version, :integer)
    field(:data, :map)
    field(:metadata, :map, default: %{})

    timestamps()
  end

  @required_fields [:aggregate_id, :aggregate_type, :version, :data]
  @optional_fields [:metadata]

  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:version, greater_than: 0)
    |> unique_constraint([:aggregate_id, :version])
  end
end

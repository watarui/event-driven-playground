defmodule Shared.Infrastructure.EventStore.Schema.Event do
  @moduledoc """
  イベントストアのスキーマ定義
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Shared.SchemaHelpers

  event_store_schema()

  schema "events" do
    field(:aggregate_id, Ecto.UUID)
    field(:aggregate_type, :string)
    field(:event_type, :string)
    field(:event_data, :map)
    field(:event_version, :integer)
    field(:schema_version, :integer, default: 1)
    field(:global_sequence, :integer)
    field(:metadata, :map, default: %{})

    timestamps()
  end

  # 必須フィールド
  @required_fields [:aggregate_id, :aggregate_type, :event_type, :event_data, :event_version]
  # オプションフィールド
  @optional_fields [:metadata, :schema_version, :global_sequence]

  @doc """
  イベントのチェンジセットを作成する
  """
  def changeset(event, attrs) do
    event
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:event_version, greater_than: 0)
    |> unique_constraint([:aggregate_id, :event_version])
  end
end

defmodule Shared.Infrastructure.EventStore.Schema.ArchivedEvent do
  @moduledoc """
  アーカイブされたイベントのスキーマ
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Shared.SchemaHelpers

  @primary_key {:id, :binary_id, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  event_store_schema()

  schema "archived_events" do
    field(:aggregate_id, :binary_id)
    field(:aggregate_type, :string)
    field(:event_type, :string)
    field(:event_version, :integer)
    field(:event_data, :map)
    field(:metadata, :map)
    field(:event_timestamp, :utc_datetime_usec)
    field(:archived_at, :utc_datetime_usec)

    timestamps()
  end

  @doc false
  def changeset(archived_event, attrs) do
    archived_event
    |> cast(attrs, [
      :id,
      :aggregate_id,
      :aggregate_type,
      :event_type,
      :event_version,
      :event_data,
      :metadata,
      :event_timestamp,
      :archived_at
    ])
    |> validate_required([
      :id,
      :aggregate_id,
      :aggregate_type,
      :event_type,
      :event_version,
      :event_data,
      :event_timestamp,
      :archived_at
    ])
  end
end

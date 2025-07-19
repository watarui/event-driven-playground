defmodule Shared.Infrastructure.DeadLetterQueue.DeadLetter do
  @moduledoc """
  デッドレターのスキーマ定義
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Shared.SchemaHelpers

  @primary_key {:id, :binary_id, autogenerate: true}
  @timestamps_opts [type: :utc_datetime]
  event_store_schema()

  schema "dead_letters" do
    field(:source, :string)
    field(:message, :string)
    field(:error_message, :string)
    field(:error_details, :map)
    field(:metadata, :map)
    field(:status, :string, default: "pending")
    field(:reprocessed_at, :utc_datetime)
    field(:reprocess_result, :string)

    timestamps()
  end

  @required_fields [:source, :message, :error_message]
  @optional_fields [:error_details, :metadata, :status, :reprocessed_at, :reprocess_result]

  def changeset(dead_letter, attrs) do
    dead_letter
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, ["pending", "reprocessed", "reprocess_failed", "deleted"])
    |> validate_length(:source, max: 100)
    |> validate_length(:error_message, max: 500)
  end
end

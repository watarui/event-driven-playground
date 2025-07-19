defmodule Shared.Infrastructure.Idempotency.IdempotencyRecord do
  @moduledoc """
  べき等性レコードのEctoスキーマ
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Shared.SchemaHelpers

  @primary_key {:id, :binary_id, autogenerate: true}
  event_store_schema()

  schema "idempotency_records" do
    field(:key, :string)
    field(:result, :map)
    field(:expires_at, :utc_datetime)
    field(:created_at, :utc_datetime)
    field(:updated_at, :utc_datetime)
  end

  @required_fields [:key, :result, :expires_at]
  @optional_fields [:created_at, :updated_at]

  def changeset(record, attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    attrs =
      attrs
      |> Map.put_new(:created_at, now)
      |> Map.put(:updated_at, now)

    record
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:key, max: 255)
    |> unique_constraint(:key)
  end
end

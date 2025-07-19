defmodule QueryService.Domain.Models.Category do
  @moduledoc """
  カテゴリの読み取りモデル

  クエリ側で使用するカテゴリのデータ構造を定義します
  """

  @enforce_keys [:id, :name, :created_at, :updated_at]
  defstruct [
    :id,
    :name,
    :description,
    :parent_id,
    :active,
    :product_count,
    :created_at,
    :updated_at
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          description: String.t() | nil,
          parent_id: String.t() | nil,
          active: boolean(),
          product_count: integer() | nil,
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @doc """
  マップからカテゴリモデルを生成する
  """
  @spec from_map(map()) :: {:ok, t()} | {:error, String.t()}
  def from_map(params) when is_map(params) do
    with {:ok, id} <- validate_field(params, "id", :string),
         {:ok, name} <- validate_field(params, "name", :string),
         {:ok, created_at} <- validate_field(params, "created_at", :datetime),
         {:ok, updated_at} <- validate_field(params, "updated_at", :datetime) do
      {:ok,
       %__MODULE__{
         id: id,
         name: name,
         description: params["description"] || params[:description],
         parent_id: params["parent_id"] || params[:parent_id],
         active: params["active"] || params[:active] || true,
         product_count: params["product_count"] || params[:product_count] || 0,
         created_at: created_at,
         updated_at: updated_at
       }}
    end
  end

  defp validate_field(params, field, :string) do
    case params[field] || params[String.to_atom(field)] do
      nil -> {:error, "#{field} is required"}
      value when is_binary(value) -> {:ok, value}
      _ -> {:error, "#{field} must be a string"}
    end
  end

  defp validate_field(params, field, :datetime) do
    case params[field] || params[String.to_atom(field)] do
      nil ->
        {:error, "#{field} is required"}

      %DateTime{} = value ->
        {:ok, value}

      value when is_binary(value) ->
        case DateTime.from_iso8601(value) do
          {:ok, datetime, _} -> {:ok, datetime}
          _ -> {:error, "Invalid datetime format for #{field}"}
        end

      _ ->
        {:error, "#{field} must be a datetime"}
    end
  end

  defimpl Jason.Encoder do
    def encode(category, opts) do
      Jason.Encode.map(
        %{
          id: category.id,
          name: category.name,
          description: category.description,
          parent_id: category.parent_id,
          active: category.active,
          product_count: category.product_count,
          created_at: DateTime.to_iso8601(category.created_at),
          updated_at: DateTime.to_iso8601(category.updated_at)
        },
        opts
      )
    end
  end
end

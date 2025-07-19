defmodule QueryService.Domain.Models.Product do
  @moduledoc """
  商品の読み取りモデル

  クエリ側で使用する商品のデータ構造を定義します
  """

  @enforce_keys [:id, :name, :price, :currency, :category_id, :created_at, :updated_at]
  defstruct [
    :id,
    :name,
    :description,
    :price,
    :currency,
    :category_id,
    :category_name,
    :stock_quantity,
    :active,
    :created_at,
    :updated_at
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          description: String.t() | nil,
          price: Decimal.t(),
          currency: String.t(),
          category_id: String.t(),
          category_name: String.t() | nil,
          stock_quantity: integer(),
          active: boolean(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @doc """
  マップから商品モデルを生成する
  """
  @spec from_map(map()) :: {:ok, t()} | {:error, String.t()}
  def from_map(params) when is_map(params) do
    with {:ok, id} <- validate_field(params, "id", :string),
         {:ok, name} <- validate_field(params, "name", :string),
         {:ok, price} <- validate_field(params, "price", :decimal),
         {:ok, currency} <- validate_field(params, "currency", :string),
         {:ok, category_id} <- validate_field(params, "category_id", :string),
         {:ok, created_at} <- validate_field(params, "created_at", :datetime),
         {:ok, updated_at} <- validate_field(params, "updated_at", :datetime) do
      {:ok,
       %__MODULE__{
         id: id,
         name: name,
         description: params["description"] || params[:description],
         price: price,
         currency: currency,
         category_id: category_id,
         category_name: params["category_name"] || params[:category_name],
         stock_quantity: params["stock_quantity"] || params[:stock_quantity] || 0,
         active: params["active"] || params[:active] || true,
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

  defp validate_field(params, field, :decimal) do
    case params[field] || params[String.to_atom(field)] do
      nil ->
        {:error, "#{field} is required"}

      %Decimal{} = value ->
        {:ok, value}

      value when is_number(value) ->
        {:ok, Decimal.new(value)}

      value when is_binary(value) ->
        case Decimal.parse(value) do
          {decimal, ""} -> {:ok, decimal}
          _ -> {:error, "Invalid decimal format for #{field}"}
        end

      _ ->
        {:error, "#{field} must be a number"}
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
    def encode(product, opts) do
      Jason.Encode.map(
        %{
          id: product.id,
          name: product.name,
          description: product.description,
          price: Decimal.to_string(product.price),
          currency: product.currency,
          category_id: product.category_id,
          category_name: product.category_name,
          stock_quantity: product.stock_quantity,
          active: product.active,
          created_at: DateTime.to_iso8601(product.created_at),
          updated_at: DateTime.to_iso8601(product.updated_at)
        },
        opts
      )
    end
  end
end

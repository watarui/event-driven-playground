defmodule Shared.Domain.ValueObjects.ProductName do
  @moduledoc """
  商品名を表す値オブジェクト

  商品名のバリデーションと正規化を提供します
  """

  @enforce_keys [:value]
  defstruct [:value]

  @type t :: %__MODULE__{value: String.t()}

  @max_length 100
  @min_length 1

  @doc """
  新しい ProductName を作成する

  ## 例

      iex> ProductName.new("ノートパソコン")
      {:ok, %ProductName{value: "ノートパソコン"}}

      iex> ProductName.new("")
      {:error, "Name cannot be empty"}

      iex> ProductName.new(String.duplicate("a", 101))
      {:error, "Name too long (max 100 characters)"}
  """
  @spec new(String.t()) :: {:ok, t()} | {:error, String.t()}
  def new(name) when is_binary(name) do
    trimmed = String.trim(name)

    cond do
      String.length(trimmed) < @min_length ->
        {:error, "Name cannot be empty"}

      String.length(trimmed) > @max_length ->
        {:error, "Name too long (max #{@max_length} characters)"}

      true ->
        {:ok, %__MODULE__{value: trimmed}}
    end
  end

  def new(_), do: {:error, "Invalid name"}

  @doc """
  新しい ProductName を作成する（例外を発生させる）

  ## 例

      iex> ProductName.new!("ノートパソコン")
      %ProductName{value: "ノートパソコン"}

      iex> ProductName.new!("")
      ** (ArgumentError) Name cannot be empty
  """
  @spec new!(String.t()) :: t()
  def new!(name) do
    case new(name) do
      {:ok, product_name} -> product_name
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @doc """
  ProductName を文字列に変換する
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{value: value}), do: value

  defimpl String.Chars do
    def to_string(%{value: value}), do: value
  end

  defimpl Jason.Encoder do
    def encode(%{value: value}, opts) do
      Jason.Encode.string(value, opts)
    end
  end
end

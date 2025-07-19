defmodule Shared.Domain.ValueObjects.CategoryName do
  @moduledoc """
  カテゴリ名を表す値オブジェクト

  カテゴリ名のバリデーションと正規化を提供します
  """

  @enforce_keys [:value]
  defstruct [:value]

  @type t :: %__MODULE__{value: String.t()}

  @max_length 50
  @min_length 1

  @doc """
  新しい CategoryName を作成する

  ## 例

      iex> CategoryName.new("電化製品")
      {:ok, %CategoryName{value: "電化製品"}}

      iex> CategoryName.new("")
      {:error, "Name cannot be empty"}

      iex> CategoryName.new(String.duplicate("a", 51))
      {:error, "Name too long (max 50 characters)"}
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

  def new(_), do: {:error, "Invalid category name"}

  @doc """
  新しい CategoryName を作成する（例外を発生させる）

  ## 例

      iex> CategoryName.new!("電化製品")
      %CategoryName{value: "電化製品"}

      iex> CategoryName.new!("")
      ** (ArgumentError) Name cannot be empty
  """
  @spec new!(String.t()) :: t()
  def new!(name) do
    case new(name) do
      {:ok, category_name} -> category_name
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @doc """
  CategoryName を文字列に変換する
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

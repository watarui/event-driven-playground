defmodule Shared.Domain.ValueObjects.EntityId do
  @moduledoc """
  エンティティ ID を表す値オブジェクト

  UUID v4 形式の ID を管理し、型安全性を提供します
  """

  @enforce_keys [:value]
  defstruct [:value]

  @type t :: %__MODULE__{value: String.t()}

  @doc """
  新しいエンティティ ID を生成する
  """
  @spec generate() :: t()
  def generate do
    %__MODULE__{value: UUID.uuid4()}
  end

  @doc """
  文字列から EntityId を作成する

  ## 例

      iex> EntityId.from_string("550e8400-e29b-41d4-a716-446655440000")
      {:ok, %EntityId{value: "550e8400-e29b-41d4-a716-446655440000"}}

      iex> EntityId.from_string("invalid-uuid")
      {:error, "Invalid UUID"}
  """
  @spec from_string(String.t()) :: {:ok, t()} | {:error, String.t()}
  def from_string(id) when is_binary(id) do
    case UUID.info(id) do
      {:ok, _} -> {:ok, %__MODULE__{value: id}}
      _ -> {:error, "Invalid UUID"}
    end
  end

  def from_string(_), do: {:error, "Invalid UUID"}

  @doc """
  EntityId を文字列に変換する
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{value: value}), do: value

  @doc """
  任意の形式の ID をバイナリ UUID に変換する

  イベントストアやデータベースで使用するバイナリ形式に変換します。
  """
  @spec to_binary(any()) :: binary() | nil
  def to_binary(nil), do: nil

  def to_binary(%__MODULE__{value: value}) do
    to_binary(value)
  end

  def to_binary(%{"value" => value}) when is_binary(value) do
    to_binary(value)
  end

  def to_binary(id) when is_binary(id) and byte_size(id) == 36 do
    # UUID ライブラリはバイナリ形式への変換をサポートしていないため、
    # 文字列形式のまま返す（Firestore では文字列形式で保存）
    id
  end

  def to_binary(id) when is_binary(id) and byte_size(id) == 16 do
    # 既にバイナリ UUID
    id
  end

  def to_binary(_), do: nil

  @doc """
  バイナリ UUID から EntityId を作成する
  """
  @spec from_binary(binary()) :: {:ok, t()} | {:error, String.t()}
  def from_binary(binary) when is_binary(binary) and byte_size(binary) == 16 do
    # UUID ライブラリはバイナリ形式からの変換をサポートしていないため、
    # この機能は一時的に無効化（Firestore では文字列形式で保存）
    {:error, "Binary UUID conversion not supported"}
  end

  def from_binary(_), do: {:error, "Invalid binary UUID"}

  defimpl String.Chars do
    def to_string(%{value: value}), do: value
  end

  defimpl Jason.Encoder do
    def encode(%{value: value}, opts) do
      Jason.Encode.string(value, opts)
    end
  end
end

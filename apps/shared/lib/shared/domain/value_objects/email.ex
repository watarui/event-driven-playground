defmodule Shared.Domain.ValueObjects.Email do
  @moduledoc """
  メールアドレス値オブジェクト
  """

  @email_regex ~r/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/

  @type t :: %__MODULE__{
          value: String.t()
        }

  @enforce_keys [:value]
  defstruct [:value]

  @doc """
  メールアドレス値オブジェクトを作成する
  """
  @spec new(String.t()) :: {:ok, t()} | {:error, :invalid_email}
  def new(email) when is_binary(email) do
    normalized = String.trim(email) |> String.downcase()

    if valid_email?(normalized) do
      {:ok, %__MODULE__{value: normalized}}
    else
      {:error, :invalid_email}
    end
  end

  def new(_), do: {:error, :invalid_email}

  @doc """
  メールアドレス値オブジェクトを作成する（例外版）
  """
  @spec new!(String.t()) :: t()
  def new!(email) do
    case new(email) do
      {:ok, email_obj} -> email_obj
      {:error, :invalid_email} -> raise ArgumentError, "Invalid email address: #{inspect(email)}"
    end
  end

  @doc """
  文字列に変換する
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{value: value}), do: value

  @doc """
  ドメイン部分を取得する
  """
  @spec domain(t()) :: String.t()
  def domain(%__MODULE__{value: value}) do
    [_, domain] = String.split(value, "@", parts: 2)
    domain
  end

  @doc """
  ローカル部分を取得する
  """
  @spec local_part(t()) :: String.t()
  def local_part(%__MODULE__{value: value}) do
    [local, _] = String.split(value, "@", parts: 2)
    local
  end

  @doc """
  同じメールアドレスかチェックする
  """
  @spec equals?(t(), t()) :: boolean()
  def equals?(%__MODULE__{value: value1}, %__MODULE__{value: value2}) do
    value1 == value2
  end

  # Private functions

  defp valid_email?(email) do
    Regex.match?(@email_regex, email)
  end

  defimpl String.Chars do
    def to_string(email), do: email.value
  end

  defimpl Jason.Encoder do
    def encode(email, opts) do
      Jason.Encode.string(email.value, opts)
    end
  end
end

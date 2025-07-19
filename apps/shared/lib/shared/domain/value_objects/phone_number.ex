defmodule Shared.Domain.ValueObjects.PhoneNumber do
  @moduledoc """
  電話番号値オブジェクト

  国際電話番号形式（E.164）をサポート
  """

  @phone_regex ~r/^\+?[1-9]\d{1,14}$/

  @type t :: %__MODULE__{
          value: String.t(),
          country_code: String.t() | nil,
          national_number: String.t()
        }

  @enforce_keys [:value, :national_number]
  defstruct [:value, :country_code, :national_number]

  @doc """
  電話番号値オブジェクトを作成する
  """
  @spec new(String.t(), keyword()) :: {:ok, t()} | {:error, :invalid_phone_number}
  def new(number, opts \\ [])

  def new(number, opts) when is_binary(number) do
    default_country_code = Keyword.get(opts, :default_country_code, "+81")
    normalized = normalize_number(number, default_country_code)

    if valid_phone_number?(normalized) do
      {country_code, national_number} = parse_number(normalized)

      {:ok,
       %__MODULE__{
         value: normalized,
         country_code: country_code,
         national_number: national_number
       }}
    else
      {:error, :invalid_phone_number}
    end
  end

  def new(_, _), do: {:error, :invalid_phone_number}

  @doc """
  電話番号値オブジェクトを作成する（例外版）
  """
  @spec new!(String.t(), keyword()) :: t()
  def new!(number, opts \\ []) do
    case new(number, opts) do
      {:ok, phone} ->
        phone

      {:error, :invalid_phone_number} ->
        raise ArgumentError, "Invalid phone number: #{inspect(number)}"
    end
  end

  @doc """
  文字列に変換する
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{value: value}), do: value

  @doc """
  国際形式で表示する
  """
  @spec format_international(t()) :: String.t()
  def format_international(%__MODULE__{value: value}), do: value

  @doc """
  国内形式で表示する
  """
  @spec format_national(t()) :: String.t()
  def format_national(%__MODULE__{national_number: national}) do
    # 日本の電話番号の場合の例
    case String.length(national) do
      # 固定電話
      10 ->
        area = String.slice(national, 0, 2)
        exchange = String.slice(national, 2, 4)
        subscriber = String.slice(national, 6, 4)
        "0#{area}-#{exchange}-#{subscriber}"

      # 携帯電話
      11 ->
        area = String.slice(national, 0, 3)
        exchange = String.slice(national, 3, 4)
        subscriber = String.slice(national, 7, 4)
        "0#{area}-#{exchange}-#{subscriber}"

      _ ->
        "0#{national}"
    end
  end

  @doc """
  同じ電話番号かチェックする
  """
  @spec equals?(t(), t()) :: boolean()
  def equals?(%__MODULE__{value: value1}, %__MODULE__{value: value2}) do
    value1 == value2
  end

  # Private functions

  defp normalize_number(number, default_country_code) do
    cleaned = String.replace(number, ~r/[\s\-\(\)\.]+/, "")

    cond do
      String.starts_with?(cleaned, "+") ->
        cleaned

      String.starts_with?(cleaned, "0") ->
        # 国内番号形式の場合、デフォルトの国番号を付与
        default_country_code <> String.slice(cleaned, 1..-1)

      true ->
        # 既に国番号なしの形式
        default_country_code <> cleaned
    end
  end

  defp valid_phone_number?(number) do
    Regex.match?(@phone_regex, number)
  end

  defp parse_number(number) do
    # 簡易的な実装。実際はより複雑な国別ルールが必要
    cond do
      String.starts_with?(number, "+81") ->
        {"+81", String.slice(number, 3..-1)}

      String.starts_with?(number, "+1") ->
        {"+1", String.slice(number, 2..-1)}

      String.starts_with?(number, "+") ->
        # その他の国
        [country_part | _] = Regex.run(~r/^\+\d{1,3}/, number)
        {country_part, String.slice(number, String.length(country_part)..-1)}

      true ->
        {nil, number}
    end
  end

  defimpl String.Chars do
    def to_string(phone), do: phone.value
  end

  defimpl Jason.Encoder do
    def encode(phone, opts) do
      Jason.Encode.string(phone.value, opts)
    end
  end
end

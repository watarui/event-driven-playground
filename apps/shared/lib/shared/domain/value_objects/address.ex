defmodule Shared.Domain.ValueObjects.Address do
  @moduledoc """
  住所値オブジェクト
  """

  @type t :: %__MODULE__{
          street: String.t(),
          city: String.t(),
          state_or_province: String.t() | nil,
          postal_code: String.t(),
          country: String.t()
        }

  @enforce_keys [:street, :city, :postal_code, :country]
  defstruct [:street, :city, :state_or_province, :postal_code, :country]

  @doc """
  住所値オブジェクトを作成する
  """
  @spec new(map()) :: {:ok, t()} | {:error, atom()}
  def new(attrs) when is_map(attrs) do
    with :ok <- validate_required_fields(attrs),
         :ok <- validate_postal_code(attrs.postal_code, attrs.country) do
      {:ok,
       %__MODULE__{
         street: normalize_string(attrs.street),
         city: normalize_string(attrs.city),
         state_or_province: normalize_string(attrs[:state_or_province]),
         postal_code: normalize_postal_code(attrs.postal_code),
         country: normalize_country(attrs.country)
       }}
    end
  end

  def new(_), do: {:error, :invalid_address}

  @doc """
  住所値オブジェクトを作成する（例外版）
  """
  @spec new!(map()) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, address} ->
        address

      {:error, reason} ->
        raise ArgumentError, "Invalid address: #{reason}"
    end
  end

  @doc """
  フォーマットされた住所文字列を返す
  """
  @spec format(t(), keyword()) :: String.t()
  def format(%__MODULE__{} = address, opts \\ []) do
    locale = Keyword.get(opts, :locale, :en)

    case locale do
      :ja ->
        format_japanese(address)

      :en ->
        format_english(address)

      _ ->
        format_english(address)
    end
  end

  @doc """
  一行形式の住所を返す
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = address) do
    parts = [
      address.street,
      address.city,
      address.state_or_province,
      address.postal_code,
      address.country
    ]

    parts
    |> Enum.reject(&is_nil/1)
    |> Enum.join(", ")
  end

  @doc """
  同じ住所かチェックする
  """
  @spec equals?(t(), t()) :: boolean()
  def equals?(%__MODULE__{} = addr1, %__MODULE__{} = addr2) do
    addr1.street == addr2.street &&
      addr1.city == addr2.city &&
      addr1.state_or_province == addr2.state_or_province &&
      addr1.postal_code == addr2.postal_code &&
      addr1.country == addr2.country
  end

  @doc """
  配送可能な国かチェックする
  """
  @spec shippable?(t(), [String.t()]) :: boolean()
  def shippable?(%__MODULE__{country: country}, allowed_countries) do
    Enum.member?(allowed_countries, country)
  end

  # Private functions

  defp validate_required_fields(attrs) do
    required = [:street, :city, :postal_code, :country]

    missing =
      Enum.filter(required, fn field ->
        value = Map.get(attrs, field)
        is_nil(value) || (is_binary(value) && String.trim(value) == "")
      end)

    if Enum.empty?(missing) do
      :ok
    else
      {:error, {:missing_fields, missing}}
    end
  end

  defp validate_postal_code(postal_code, country) do
    regex = postal_code_regex(country)

    if regex && !Regex.match?(regex, postal_code) do
      {:error, :invalid_postal_code}
    else
      :ok
    end
  end

  defp postal_code_regex("JP"), do: ~r/^\d{3}-?\d{4}$/
  defp postal_code_regex("US"), do: ~r/^\d{5}(-\d{4})?$/
  defp postal_code_regex("CA"), do: ~r/^[A-Z]\d[A-Z]\s?\d[A-Z]\d$/i
  defp postal_code_regex("GB"), do: ~r/^[A-Z]{1,2}\d[A-Z\d]?\s?\d[A-Z]{2}$/i
  defp postal_code_regex(_), do: nil

  defp normalize_string(nil), do: nil
  defp normalize_string(str) when is_binary(str), do: String.trim(str)

  defp normalize_postal_code(postal_code) do
    String.replace(postal_code, " ", "") |> String.upcase()
  end

  defp normalize_country(country) do
    # ISO 3166-1 alpha-2 形式に正規化
    String.upcase(country) |> String.slice(0, 2)
  end

  defp format_japanese(address) do
    """
    〒#{address.postal_code}
    #{address.country} #{address.state_or_province || ""}#{address.city}
    #{address.street}
    """
    |> String.trim()
  end

  defp format_english(address) do
    lines = [
      address.street,
      [address.city, address.state_or_province] |> Enum.reject(&is_nil/1) |> Enum.join(", "),
      address.postal_code,
      address.country
    ]

    Enum.join(lines, "\n")
  end

  defimpl String.Chars do
    def to_string(address) do
      Shared.Domain.ValueObjects.Address.to_string(address)
    end
  end

  defimpl Jason.Encoder do
    def encode(address, opts) do
      Jason.Encode.map(
        %{
          street: address.street,
          city: address.city,
          state_or_province: address.state_or_province,
          postal_code: address.postal_code,
          country: address.country
        },
        opts
      )
    end
  end
end

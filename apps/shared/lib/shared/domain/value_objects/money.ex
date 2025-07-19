defmodule Shared.Domain.ValueObjects.Money do
  @moduledoc """
  金額を表す値オブジェクト

  多通貨に対応し、精度の高い金額計算を提供します。
  通貨コードは ISO 4217 形式を使用します。
  """

  @enforce_keys [:amount, :currency]
  defstruct [:amount, :currency]

  @type t :: %__MODULE__{
          amount: Decimal.t(),
          currency: String.t()
        }

  # サポートする通貨とその小数点以下桁数
  @currencies %{
    # 日本円
    "JPY" => 0,
    # 米ドル
    "USD" => 2,
    # ユーロ
    "EUR" => 2,
    # 英ポンド
    "GBP" => 2,
    # 中国元
    "CNY" => 2,
    # 韓国ウォン
    "KRW" => 0,
    # ビットコイン
    "BTC" => 8
  }

  @doc """
  新しい Money オブジェクトを作成する

  ## 例

      iex> Money.new(1000)
      {:ok, %Money{amount: #Decimal<1000>, currency: "JPY"}}
      
      iex> Money.new(100.50, "USD")
      {:ok, %Money{amount: #Decimal<100.50>, currency: "USD"}}

      iex> Money.new(-100)
      {:error, "Amount must be non-negative"}
  """
  @spec new(number() | Decimal.t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def new(amount, currency \\ "JPY")

  def new(%Decimal{} = amount, currency) do
    with :ok <- validate_currency(currency),
         :ok <- validate_amount(amount) do
      {:ok,
       %__MODULE__{
         amount: round_to_currency_precision(amount, currency),
         currency: currency
       }}
    end
  end

  def new(amount, currency) when is_number(amount) do
    decimal_amount = to_decimal(amount)
    new(decimal_amount, currency)
  end

  def new(_, _), do: {:error, "Invalid amount"}

  @doc """
  文字列から Money オブジェクトを作成する
  """
  @spec from_string(String.t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def from_string(amount_str, currency \\ "JPY") when is_binary(amount_str) do
    case Decimal.parse(amount_str) do
      {amount, ""} ->
        new(amount, currency)

      _ ->
        {:error, "Invalid amount format"}
    end
  end

  @doc """
  2つの Money オブジェクトを加算する
  """
  @spec add(t(), t()) :: {:ok, t()} | {:error, String.t()}
  def add(%__MODULE__{currency: c1} = m1, %__MODULE__{currency: c2} = m2) when c1 == c2 do
    {:ok,
     %__MODULE__{
       amount: Decimal.add(m1.amount, m2.amount),
       currency: c1
     }}
  end

  def add(_, _), do: {:error, "Currency mismatch"}

  @doc """
  Money オブジェクトから別の Money を減算する
  """
  @spec subtract(t(), t()) :: {:ok, t()} | {:error, String.t()}
  def subtract(%__MODULE__{currency: c1} = m1, %__MODULE__{currency: c2} = m2) when c1 == c2 do
    result = Decimal.sub(m1.amount, m2.amount)

    if Decimal.compare(result, 0) == :lt do
      {:error, "Result would be negative"}
    else
      {:ok, %__MODULE__{amount: result, currency: c1}}
    end
  end

  def subtract(_, _), do: {:error, "Currency mismatch"}

  @doc """
  Money オブジェクトに数値を掛ける
  """
  @spec multiply(t(), number()) :: {:ok, t()} | {:error, String.t()}
  def multiply(%__MODULE__{} = money, multiplier)
      when is_number(multiplier) and multiplier >= 0 do
    # Decimal.new は整数または文字列のみ受け付けるため、数値を文字列に変換
    decimal_multiplier =
      if is_float(multiplier) do
        multiplier |> Float.to_string() |> Decimal.new()
      else
        Decimal.new(multiplier)
      end

    {:ok,
     %__MODULE__{
       amount: Decimal.mult(money.amount, decimal_multiplier),
       currency: money.currency
     }}
  end

  def multiply(_, _), do: {:error, "Invalid multiplier"}

  @doc """
  2つの Money オブジェクトを比較する
  """
  @spec compare(t(), t()) :: :lt | :eq | :gt | {:error, String.t()}
  def compare(%__MODULE__{currency: c1} = m1, %__MODULE__{currency: c2} = m2) when c1 == c2 do
    Decimal.compare(m1.amount, m2.amount)
  end

  def compare(_, _), do: {:error, "Currency mismatch"}

  @doc """
  Money を整数値（円）として取得する
  """
  @spec to_integer(t()) :: integer()
  def to_integer(%__MODULE__{amount: amount}) do
    amount |> Decimal.round(0) |> Decimal.to_integer()
  end

  @doc """
  Money を文字列として表示する
  """
  @spec to_string(t(), keyword()) :: String.t()
  def to_string(%__MODULE__{amount: amount, currency: currency}, opts \\ []) do
    format = Keyword.get(opts, :format, :standard)

    case format do
      :standard ->
        "#{currency} #{format_amount(amount, currency)}"

      :symbol ->
        symbol = currency_symbol(currency)
        "#{symbol}#{format_amount(amount, currency)}"

      :accounting ->
        formatted = format_amount(amount, currency)
        "#{currency} #{formatted}"
    end
  end

  @doc """
  通貨を変換する（為替レート機能）
  """
  @spec convert(t(), String.t(), Decimal.t()) :: {:ok, t()} | {:error, String.t()}
  def convert(%__MODULE__{} = money, target_currency, exchange_rate) do
    with :ok <- validate_currency(target_currency),
         {:ok, rate} <- validate_exchange_rate(exchange_rate) do
      converted_amount = Decimal.mult(money.amount, rate)
      new(converted_amount, target_currency)
    end
  end

  @doc """
  金額をゼロかチェックする
  """
  @spec zero?(t()) :: boolean()
  def zero?(%__MODULE__{amount: amount}) do
    Decimal.compare(amount, Decimal.new(0)) == :eq
  end

  @doc """
  サポートされている通貨かチェックする
  """
  @spec supported_currency?(String.t()) :: boolean()
  def supported_currency?(currency) do
    Map.has_key?(@currencies, currency)
  end

  @doc """
  通貨の小数点以下桁数を取得する
  """
  @spec currency_precision(String.t()) :: integer() | nil
  def currency_precision(currency) do
    Map.get(@currencies, currency)
  end

  # Private functions

  defp validate_currency(currency) do
    if supported_currency?(currency) do
      :ok
    else
      {:error, "Unsupported currency: #{currency}"}
    end
  end

  defp validate_amount(amount) do
    if Decimal.compare(amount, Decimal.new(0)) in [:gt, :eq] do
      :ok
    else
      {:error, "Amount must be non-negative"}
    end
  end

  defp validate_exchange_rate(rate) do
    decimal_rate = to_decimal(rate)

    if Decimal.compare(decimal_rate, Decimal.new(0)) == :gt do
      {:ok, decimal_rate}
    else
      {:error, "Exchange rate must be positive"}
    end
  end

  defp to_decimal(value) when is_float(value) do
    value |> Float.to_string() |> Decimal.new()
  end

  defp to_decimal(value) when is_integer(value) do
    Decimal.new(value)
  end

  defp to_decimal(%Decimal{} = value), do: value

  defp round_to_currency_precision(amount, currency) do
    precision = Map.get(@currencies, currency, 2)
    Decimal.round(amount, precision)
  end

  defp format_amount(amount, currency) do
    precision = Map.get(@currencies, currency, 2)

    amount
    |> Decimal.round(precision)
    |> Decimal.to_string(:normal)
    |> add_thousand_separators()
  end

  defp add_thousand_separators(amount_str) do
    [integer_part | decimal_part] = String.split(amount_str, ".")

    formatted_integer =
      integer_part
      |> String.graphemes()
      |> Enum.reverse()
      |> Enum.chunk_every(3)
      |> Enum.join(",")
      |> String.reverse()

    case decimal_part do
      [] -> formatted_integer
      [decimals] -> "#{formatted_integer}.#{decimals}"
    end
  end

  defp currency_symbol("JPY"), do: "¥"
  defp currency_symbol("USD"), do: "$"
  defp currency_symbol("EUR"), do: "€"
  defp currency_symbol("GBP"), do: "£"
  defp currency_symbol("CNY"), do: "¥"
  defp currency_symbol("KRW"), do: "₩"
  defp currency_symbol("BTC"), do: "₿"
  defp currency_symbol(_), do: ""

  defimpl String.Chars do
    def to_string(money), do: Shared.Domain.ValueObjects.Money.to_string(money)
  end

  defimpl Jason.Encoder do
    def encode(%{amount: amount, currency: currency}, opts) do
      Jason.Encode.map(
        %{
          amount: Decimal.to_string(amount),
          currency: currency
        },
        opts
      )
    end
  end
end

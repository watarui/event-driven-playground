defmodule Shared.Telemetry.Span do
  @moduledoc """
  OpenTelemetry スパンのヘルパー関数

  トレーシングスパンを簡単に作成・管理するための関数を提供します
  """

  require OpenTelemetry.Tracer, as: Tracer

  @doc """
  スパン内でコードを実行する

  ## 例

      Span.with_span "my_operation", %{user_id: "123"} do
        # 処理
        {:ok, result}
      end
  """
  def with_span(name, attributes \\ %{}, fun) do
    Tracer.with_span name, %{attributes: normalize_attributes(attributes)} do
      # funが関数かdo-blockキーワードリストかチェック
      result =
        if is_function(fun) do
          fun.()
        else
          # do-block の場合
          case Keyword.fetch(fun, :do) do
            {:ok, expr} -> expr
            :error -> raise ArgumentError, "Expected a function or do-block"
          end
        end

      # エラーの場合はスパンにエラー情報を記録
      case result do
        {:error, reason} ->
          Tracer.set_status(:error, format_error(reason))

        _ ->
          :ok
      end

      result
    end
  end

  @doc """
  現在のスパンに属性を追加する
  """
  def set_attributes(attributes) do
    Tracer.set_attributes(normalize_attributes(attributes))
  end

  @doc """
  現在のスパンにイベントを追加する
  """
  def add_event(name, attributes \\ %{}) do
    Tracer.add_event(name, %{attributes: normalize_attributes(attributes)})
  end

  @doc """
  現在のスパンのステータスを設定する
  """
  def set_status(:ok), do: Tracer.set_status(:ok, "")
  def set_status(:error, message), do: Tracer.set_status(:error, message)

  @doc """
  現在のトレースIDを取得する
  """
  def get_trace_id do
    case OpenTelemetry.Tracer.current_span_ctx() do
      :undefined ->
        nil

      span_ctx ->
        {:ok, trace_id} = OpenTelemetry.Span.trace_id(span_ctx)
        trace_id |> :io_lib.format("~32.16.0b") |> to_string()
    end
  end

  @doc """
  現在のスパンIDを取得する
  """
  def get_span_id do
    case OpenTelemetry.Tracer.current_span_ctx() do
      :undefined ->
        nil

      span_ctx ->
        {:ok, span_id} = OpenTelemetry.Span.span_id(span_ctx)
        span_id |> :io_lib.format("~16.16.0b") |> to_string()
    end
  end

  # Private functions

  defp normalize_attributes(attributes) when is_map(attributes) do
    Enum.reduce(attributes, %{}, fn {key, value}, acc ->
      Map.put(acc, to_string(key), format_value(value))
    end)
  end

  defp normalize_attributes(_), do: %{}

  defp format_value(value) when is_binary(value), do: value
  defp format_value(value) when is_atom(value), do: to_string(value)
  defp format_value(value) when is_number(value), do: value
  defp format_value(value) when is_boolean(value), do: value
  defp format_value(%{__struct__: _} = struct), do: inspect(struct)
  defp format_value(value), do: inspect(value)

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)
end

defmodule Shared.Telemetry.Tracing.MessagePropagator do
  @moduledoc """
  メッセージベースの通信（コマンド、イベント、クエリ）におけるトレーシングコンテキストの伝播を処理
  """

  require Logger
  alias Shared.Telemetry.Span

  @doc """
  コマンドディスパッチのトレーシングをラップ
  """
  def wrap_command_dispatch(command, fun) do
    span_name = "command.dispatch.#{command.__struct__ |> Module.split() |> List.last()}"
    
    Span.with_span span_name, %{attributes: build_command_attributes(command)} do
      try do
        result = fun.(command)
        record_command_result(result)
        result
      rescue
        e ->
          Span.set_error(Exception.message(e))
          reraise e, __STACKTRACE__
      end
    end
  end

  @doc """
  イベント発行のトレーシングをラップ
  """
  def wrap_event_publish(event, fun) do
    span_name = "event.publish.#{event.__struct__ |> Module.split() |> List.last()}"
    
    Span.with_span span_name, %{attributes: build_event_attributes(event)} do
      try do
        result = fun.(event)
        record_event_result(result)
        result
      rescue
        e ->
          Span.set_error(Exception.message(e))
          reraise e, __STACKTRACE__
      end
    end
  end

  @doc """
  クエリ実行のトレーシングをラップ
  """
  def wrap_query_execution(query, fun) do
    span_name = "query.execute.#{query.__struct__ |> Module.split() |> List.last()}"
    
    Span.with_span span_name, %{attributes: build_query_attributes(query)} do
      try do
        result = fun.(query)
        record_query_result(result)
        result
      rescue
        e ->
          Span.set_error(Exception.message(e))
          reraise e, __STACKTRACE__
      end
    end
  end

  @doc """
  メッセージからトレーシングコンテキストを抽出
  """
  def extract_context(message) do
    case Map.get(message, :metadata) do
      %{trace_context: context} -> 
        # OpenTelemetry のコンテキストを復元
        :otel_propagator_text_map.extract(context)
        
      _ -> 
        # コンテキストがない場合は何もしない
        :ok
    end
  end

  @doc """
  メッセージにトレーシングコンテキストを注入
  """
  def inject_context(message) do
    # 現在のトレーシングコンテキストを取得
    context = :otel_propagator_text_map.inject([])
    
    metadata = Map.get(message, :metadata, %{})
    updated_metadata = Map.put(metadata, :trace_context, context)
    
    Map.put(message, :metadata, updated_metadata)
  end

  # Private functions

  defp build_command_attributes(command) do
    %{
      "messaging.system" => "cqrs",
      "messaging.destination" => "command_bus",
      "messaging.operation" => "dispatch",
      "command.type" => to_string(command.__struct__),
      "command.aggregate_id" => get_aggregate_id(command)
    }
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp build_event_attributes(event) do
    %{
      "messaging.system" => "event_sourcing",
      "messaging.destination" => "event_bus",
      "messaging.operation" => "publish",
      "event.type" => to_string(event.__struct__),
      "event.aggregate_id" => get_aggregate_id(event)
    }
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp build_query_attributes(query) do
    %{
      "messaging.system" => "cqrs",
      "messaging.destination" => "query_bus",
      "messaging.operation" => "execute",
      "query.type" => to_string(query.__struct__)
    }
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp get_aggregate_id(message) do
    cond do
      Map.has_key?(message, :id) -> 
        case Map.get(message, :id) do
          %{value: value} -> value
          id when is_binary(id) -> id
          _ -> nil
        end
        
      Map.has_key?(message, :aggregate_id) -> 
        Map.get(message, :aggregate_id)
        
      true -> 
        nil
    end
  end

  defp record_command_result({:ok, _}) do
    Span.set_attribute("command.status", "success")
  end

  defp record_command_result({:error, reason}) do
    Span.set_attribute("command.status", "error")
    Span.set_attribute("command.error", inspect(reason))
  end

  defp record_command_result(_) do
    Span.set_attribute("command.status", "unknown")
  end

  defp record_event_result({:ok, _}) do
    Span.set_attribute("event.status", "published")
  end

  defp record_event_result({:error, reason}) do
    Span.set_attribute("event.status", "error")
    Span.set_attribute("event.error", inspect(reason))
  end

  defp record_event_result(_) do
    Span.set_attribute("event.status", "unknown")
  end

  defp record_query_result({:ok, _}) do
    Span.set_attribute("query.status", "success")
  end

  defp record_query_result({:error, reason}) do
    Span.set_attribute("query.status", "error") 
    Span.set_attribute("query.error", inspect(reason))
  end

  defp record_query_result(_) do
    Span.set_attribute("query.status", "unknown")
  end
end
defmodule Shared.GraphQL.ErrorHelpers do
  @moduledoc """
  GraphQL エラーハンドリングの共通ヘルパー
  
  各リゾルバーで重複しているエラーハンドリングロジックを統一します。
  """

  require Logger

  @doc """
  クエリ結果を処理し、エラーの場合は適切にハンドリングする
  
  ## 使用例
  
      case RemoteQueryBus.send_query(query) do
        {:ok, data} -> {:ok, transform_data(data)}
        error -> handle_query_error(error, "Failed to list categories")
      end
  
  または、より簡潔に:
  
      RemoteQueryBus.send_query(query)
      |> handle_query_result("Failed to list categories")
      |> case do
        {:ok, data} -> {:ok, transform_data(data)}
        error -> error
      end
  """
  def handle_query_result({:ok, data}, _error_context), do: {:ok, data}
  def handle_query_result({:error, reason}, error_context), do: handle_query_error({:error, reason}, error_context)

  @doc """
  クエリエラーを処理し、適切な GraphQL レスポンスを返す
  """
  def handle_query_error({:error, :timeout}, error_context) do
    Logger.error("#{error_context}: timeout")
    {:ok, []}
  end

  def handle_query_error({:error, :not_found}, _error_context) do
    {:error, "Not found"}
  end

  def handle_query_error({:error, reason}, error_context) do
    Logger.error("#{error_context}: #{inspect(reason)}")
    {:ok, []}
  end

  @doc """
  コマンド結果を処理し、エラーの場合は適切にハンドリングする
  """
  def handle_command_result({:ok, result}, _error_context), do: {:ok, result}
  def handle_command_result({:error, reason}, error_context), do: handle_command_error({:error, reason}, error_context)

  @doc """
  コマンドエラーを処理し、適切な GraphQL レスポンスを返す
  """
  def handle_command_error({:error, :timeout}, error_context) do
    Logger.error("#{error_context}: timeout")
    {:error, "Request timed out"}
  end

  def handle_command_error({:error, error_module, context}, _error_context) when is_atom(error_module) do
    message = format_error_message(error_module, context)
    {:error, message}
  end

  def handle_command_error({:error, reason}, error_context) do
    Logger.error("#{error_context}: #{inspect(reason)}")
    {:error, error_context}
  end

  @doc """
  エラーメッセージをフォーマット
  """
  def format_error_message(Shared.Domain.Errors.BusinessRuleError, %{rule: rule, context: context}) do
    reason = context[:reason] || "Business rule violation"
    "Business rule '#{rule}' failed: #{reason}"
  end

  def format_error_message(Shared.Domain.Errors.NotFoundError, %{resource: resource, id: id}) do
    "#{resource} with ID '#{id}' not found"
  end

  def format_error_message(Shared.Domain.Errors.ValidationError, %{field: field, reason: reason}) do
    "Validation failed for field '#{field}': #{reason}"
  end

  def format_error_message(_error_module, context) do
    "Error: #{inspect(context)}"
  end

  @doc """
  変換関数を適用し、エラーハンドリングも行う
  
  ## 使用例
  
      RemoteQueryBus.send_query(query)
      |> with_transform(&transform_categories/1, "Failed to list categories")
  """
  def with_transform(result, transform_fn, error_context) when is_function(transform_fn, 1) do
    case result do
      {:ok, data} -> 
        {:ok, transform_fn.(data)}
      error -> 
        handle_query_error(error, error_context)
    end
  end

  @doc """
  リスト変換用のヘルパー
  
  ## 使用例
  
      RemoteQueryBus.send_query(query)
      |> with_list_transform(&transform_category/1, "Failed to list categories")
  """
  def with_list_transform(result, transform_fn, error_context) when is_function(transform_fn, 1) do
    case result do
      {:ok, data} when is_list(data) -> 
        {:ok, Enum.map(data, transform_fn)}
      {:ok, data} -> 
        {:ok, transform_fn.(data)}
      error -> 
        handle_query_error(error, error_context)
    end
  end
end
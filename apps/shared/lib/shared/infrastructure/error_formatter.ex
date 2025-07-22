defmodule Shared.Infrastructure.ErrorFormatter do
  @moduledoc """
  GraphQL エラーフォーマッター

  エラーメッセージを統一的なフォーマットに変換します。
  """

  @doc """
  GraphQL エラーをフォーマットする
  """
  def format_graphql_error(error_module, context) do
    %{
      message: format_message(error_module, context),
      extensions: %{
        code: error_code(error_module),
        details: error_details(error_module, context)
      }
    }
  end

  # エラーメッセージのフォーマット
  defp format_message(Shared.Errors.ValidationError, %{message: message}) do
    "Validation failed: #{message}"
  end

  defp format_message(Shared.Errors.NotFoundError, %{resource: resource}) do
    "#{resource} not found"
  end

  defp format_message(Shared.Errors.ConflictError, %{message: message}) do
    "Conflict: #{message}"
  end

  defp format_message(Shared.Errors.UnauthorizedError, _) do
    "Unauthorized access"
  end

  defp format_message(Shared.Errors.ForbiddenError, _) do
    "Access forbidden"
  end

  defp format_message(Shared.Errors.BusinessRuleViolation, %{message: message}) do
    "Business rule violation: #{message}"
  end

  defp format_message(Shared.Errors.ConcurrencyError, _) do
    "Concurrent modification detected. Please retry."
  end

  defp format_message(Shared.Errors.InternalServerError, _) do
    "Internal server error"
  end

  defp format_message(_, %{message: message}) when is_binary(message) do
    message
  end

  defp format_message(_, _) do
    "An error occurred"
  end

  # エラーコードの取得
  defp error_code(Shared.Errors.ValidationError), do: "VALIDATION_ERROR"
  defp error_code(Shared.Errors.NotFoundError), do: "NOT_FOUND"
  defp error_code(Shared.Errors.ConflictError), do: "CONFLICT"
  defp error_code(Shared.Errors.UnauthorizedError), do: "UNAUTHORIZED"
  defp error_code(Shared.Errors.ForbiddenError), do: "FORBIDDEN"
  defp error_code(Shared.Errors.BusinessRuleViolation), do: "BUSINESS_RULE_VIOLATION"
  defp error_code(Shared.Errors.ConcurrencyError), do: "CONCURRENCY_ERROR"
  defp error_code(Shared.Errors.InternalServerError), do: "INTERNAL_SERVER_ERROR"
  defp error_code(_), do: "UNKNOWN_ERROR"

  # エラー詳細の取得
  defp error_details(Shared.Errors.ValidationError, %{details: details}) when is_map(details) do
    details
  end

  defp error_details(Shared.Errors.ValidationError, %{field: field, reason: reason}) do
    %{field: field, reason: reason}
  end

  defp error_details(Shared.Errors.NotFoundError, %{resource: resource, id: id}) do
    %{resource: resource, id: id}
  end

  defp error_details(Shared.Errors.BusinessRuleViolation, %{rule: rule}) do
    %{rule: rule}
  end

  defp error_details(_, context) do
    Map.drop(context, [:__struct__, :__exception__])
  end
end

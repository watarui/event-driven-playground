defmodule Shared.Domain.Errors.ValidationError do
  @moduledoc """
  バリデーションエラー
  """

  use Shared.Domain.Errors.DomainError

  @impl true
  def error_code, do: "VALIDATION_ERROR"

  @impl true
  def message(%{field: field}) do
    "Validation failed for field: #{field}"
  end

  def message(_), do: "Validation failed"

  @impl true
  def details(%{errors: errors}) when is_map(errors) do
    %{validation_errors: errors}
  end

  def details(%{field: field, reason: reason}) do
    %{validation_errors: %{field => reason}}
  end

  def http_status, do: 400
end

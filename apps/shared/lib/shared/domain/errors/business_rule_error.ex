defmodule Shared.Domain.Errors.BusinessRuleError do
  @moduledoc """
  ビジネスルール違反エラー
  """

  use Shared.Domain.Errors.DomainError

  @impl true
  def error_code, do: "BUSINESS_RULE_VIOLATION"

  @impl true
  def message(%{rule: rule}) do
    "Business rule violation: #{rule}"
  end

  def message(%{message: message}) do
    message
  end

  def message(_), do: "Business rule violation"

  @impl true
  def details(%{rule: rule, context: context}) do
    %{
      violated_rule: rule,
      context: context
    }
  end

  def http_status, do: 422
end

defmodule Shared.Domain.Errors.ConflictError do
  @moduledoc """
  リソースの競合エラー
  """

  use Shared.Domain.Errors.DomainError

  @impl true
  def error_code, do: "CONFLICT"

  @impl true
  def message(%{resource: resource, reason: reason}) do
    "Conflict on #{resource}: #{reason}"
  end

  def message(%{reason: reason}) do
    "Conflict: #{reason}"
  end

  def message(_), do: "Resource conflict"

  @impl true
  def details(%{resource: resource, current_version: current, expected_version: expected}) do
    %{
      resource: resource,
      current_version: current,
      expected_version: expected
    }
  end

  def http_status, do: 409
end

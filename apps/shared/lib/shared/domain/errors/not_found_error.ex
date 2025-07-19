defmodule Shared.Domain.Errors.NotFoundError do
  @moduledoc """
  リソースが見つからないエラー
  """

  use Shared.Domain.Errors.DomainError

  @impl true
  def error_code, do: "NOT_FOUND"

  @impl true
  def message(%{resource: resource, id: id}) do
    "#{resource} with id '#{id}' not found"
  end

  def message(%{resource: resource}) do
    "#{resource} not found"
  end

  def message(_), do: "Resource not found"

  @impl true
  def details(%{resource: resource, id: id}) do
    %{resource: resource, id: id}
  end

  def http_status, do: 404
end

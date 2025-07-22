defmodule ClientService.GraphQL.Middleware.ErrorHandler do
  @moduledoc """
  GraphQL エラーハンドリングミドルウェア

  ドメインエラーを GraphQL エラー形式に変換する。
  """

  @behaviour Absinthe.Middleware

  alias Shared.Infrastructure.ErrorFormatter

  @impl true
  def call(resolution, _config) do
    resolution
    |> handle_errors()
  end

  defp handle_errors(%{errors: errors} = resolution) when length(errors) > 0 do
    formatted_errors = Enum.map(errors, &format_error/1)
    %{resolution | errors: formatted_errors}
  end

  defp handle_errors(%{value: {:error, error_module, context}} = resolution)
       when is_atom(error_module) do
    error = ErrorFormatter.format_graphql_error(error_module, context)

    %{resolution | value: nil, errors: [error]}
  end

  # Ecto.Changeset の処理は削除（Firestore への移行に伴い不要）

  defp handle_errors(%{value: {:error, reason}} = resolution) when is_binary(reason) do
    %{resolution | value: nil, errors: [%{message: reason}]}
  end

  defp handle_errors(resolution), do: resolution

  defp format_error({:error, error_module, context}) when is_atom(error_module) do
    ErrorFormatter.format_graphql_error(error_module, context)
  end

  defp format_error(%{message: _} = error), do: error

  defp format_error(error) when is_binary(error) do
    %{message: error}
  end

  defp format_error(error) do
    %{message: inspect(error)}
  end
end

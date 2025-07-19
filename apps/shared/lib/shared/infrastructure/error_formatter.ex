defmodule Shared.Infrastructure.ErrorFormatter do
  @moduledoc """
  エラーレスポンスの統一フォーマッター

  ドメインエラーを一貫性のある API レスポンス形式に変換する。
  """

  alias Shared.Domain.Errors.DomainError

  @doc """
  エラーを GraphQL レスポンス形式に変換する
  """
  @spec format_graphql_error(module(), map()) :: map()
  def format_graphql_error(error_module, context \\ %{}) do
    error_map = DomainError.to_map(error_module, context)

    %{
      message: error_map.message,
      extensions: %{
        code: error_map.error_code,
        details: error_map.details,
        timestamp: error_map.timestamp
      }
    }
  end

  @doc """
  エラーを REST API レスポンス形式に変換する
  """
  @spec format_rest_error(module(), map()) :: map()
  def format_rest_error(error_module, context \\ %{}) do
    error_map = DomainError.to_map(error_module, context)

    %{
      error: %{
        code: error_map.error_code,
        message: error_map.message,
        details: error_map.details,
        timestamp: error_map.timestamp
      },
      status: DomainError.http_status(error_module)
    }
  end

  @doc """
  複数のエラーをバッチフォーマットする
  """
  @spec format_error_batch([{module(), map()}], :graphql | :rest) :: [map()]
  def format_error_batch(errors, format_type \\ :graphql) do
    Enum.map(errors, fn {error_module, context} ->
      case format_type do
        :graphql -> format_graphql_error(error_module, context)
        :rest -> format_rest_error(error_module, context)
      end
    end)
  end

  @doc """
  Ecto.Changeset エラーをドメインエラー形式に変換する
  """
  @spec format_changeset_errors(Ecto.Changeset.t()) :: map()
  def format_changeset_errors(%Ecto.Changeset{} = changeset) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Enum.reduce(opts, msg, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", to_string(value))
        end)
      end)

    format_graphql_error(Shared.Domain.Errors.ValidationError, %{errors: errors})
  end

  @doc """
  エラーレスポンスにトレース情報を追加する
  """
  @spec add_trace_info(map(), map()) :: map()
  def add_trace_info(error_response, trace_info) do
    put_in(error_response, [:extensions, :trace], trace_info)
  end
end

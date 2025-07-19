defmodule Shared.Domain.Errors.DomainError do
  @moduledoc """
  ドメインエラーの基底モジュール

  すべてのドメインエラーはこのビヘイビアを実装する。
  """

  @type error_code :: String.t()
  @type error_context :: map()

  @callback error_code() :: error_code()
  @callback message(error_context()) :: String.t()
  @callback details(error_context()) :: map()

  @doc """
  エラーを構造化された形式に変換する
  """
  @spec to_map(module(), error_context()) :: map()
  def to_map(error_module, context \\ %{}) do
    %{
      error_code: error_module.error_code(),
      message: error_module.message(context),
      details: error_module.details(context),
      timestamp: DateTime.utc_now()
    }
  end

  @doc """
  HTTPステータスコードを返す
  """
  @spec http_status(module()) :: non_neg_integer()
  def http_status(error_module) do
    if function_exported?(error_module, :http_status, 0) do
      error_module.http_status()
    else
      500
    end
  end

  defmacro __using__(_opts) do
    quote do
      @behaviour Shared.Domain.Errors.DomainError

      @impl true
      def details(_context), do: %{}

      defoverridable details: 1
    end
  end
end

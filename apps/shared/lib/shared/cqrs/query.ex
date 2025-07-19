defprotocol Shared.CQRS.Query do
  @moduledoc """
  クエリのプロトコル定義

  すべてのクエリはこのプロトコルを実装する必要がある。
  """

  @doc """
  クエリのハンドラーモジュールを返す
  """
  @spec handler(t()) :: module()
  def handler(query)

  @doc """
  クエリの対象エンティティタイプを返す
  """
  @spec entity_type(t()) :: atom()
  def entity_type(query)

  @doc """
  クエリのバリデーションを実行する
  """
  @spec validate(t()) :: :ok | {:error, map()}
  def validate(query)

  @doc """
  クエリがキャッシュ可能かどうかを返す
  """
  @spec cacheable?(t()) :: boolean()
  def cacheable?(query)

  @doc """
  キャッシュキーを生成する
  """
  @spec cache_key(t()) :: String.t() | nil
  def cache_key(query)
end

defmodule Shared.CQRS.Query.Helpers do
  @moduledoc """
  クエリ実装のためのヘルパーマクロ
  """

  defmacro __using__(opts) do
    handler = Keyword.fetch!(opts, :handler)
    entity_type = Keyword.fetch!(opts, :entity_type)
    cacheable = Keyword.get(opts, :cacheable, false)

    quote do
      @behaviour Shared.CQRS.Query

      defimpl Shared.CQRS.Query, for: __MODULE__ do
        def handler(_), do: unquote(handler)
        def entity_type(_), do: unquote(entity_type)
        def cacheable?(_), do: unquote(cacheable)

        def validate(query) do
          if function_exported?(__MODULE__, :validate, 1) do
            __MODULE__.validate(query)
          else
            :ok
          end
        end

        def cache_key(query) do
          if unquote(cacheable) && function_exported?(__MODULE__, :cache_key, 1) do
            __MODULE__.cache_key(query)
          else
            nil
          end
        end
      end
    end
  end
end

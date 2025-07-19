defprotocol Shared.CQRS.Command do
  @moduledoc """
  コマンドのプロトコル定義

  すべてのコマンドはこのプロトコルを実装する必要がある。
  これにより、動的ディスパッチと型安全性を実現する。
  """

  @doc """
  コマンドのハンドラーモジュールを返す
  """
  @spec handler(t()) :: module()
  def handler(command)

  @doc """
  コマンドのアグリゲートタイプを返す
  """
  @spec aggregate_type(t()) :: atom()
  def aggregate_type(command)

  @doc """
  コマンドの一意識別子を返す（べき等性のため）
  """
  @spec command_id(t()) :: String.t() | nil
  def command_id(command)

  @doc """
  コマンドのバリデーションを実行する
  """
  @spec validate(t()) :: :ok | {:error, map()}
  def validate(command)
end

defmodule Shared.CQRS.Command.Helpers do
  @moduledoc """
  コマンド実装のためのヘルパーマクロ
  """

  @doc """
  コマンドの共通実装を提供するマクロ

  ## 使用例

      defmodule CreateOrderCommand do
        use Shared.CQRS.Command.Helpers,
          handler: OrderCommandHandler,
          aggregate_type: :order
          
        defstruct [:user_id, :items, :shipping_address]
        
        def validate(command) do
          # カスタムバリデーション
        end
      end
  """
  defmacro __using__(opts) do
    handler = Keyword.fetch!(opts, :handler)
    aggregate_type = Keyword.fetch!(opts, :aggregate_type)

    quote do
      defimpl Shared.CQRS.Command, for: __MODULE__ do
        def handler(_), do: unquote(handler)
        def aggregate_type(_), do: unquote(aggregate_type)

        def command_id(%{id: id}) when not is_nil(id), do: to_string(id)
        def command_id(_), do: nil

        def validate(command) do
          if function_exported?(__MODULE__, :validate, 1) do
            __MODULE__.validate(command)
          else
            :ok
          end
        end
      end
    end
  end
end

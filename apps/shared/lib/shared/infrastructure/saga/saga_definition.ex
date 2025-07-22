defmodule Shared.Infrastructure.Saga.SagaDefinition do
  @moduledoc """
  Saga定義のためのビヘイビア

  長時間実行されるビジネストランザクションを実装するための
  インターフェースを定義します。
  """

  @doc """
  Saga の名前を返す
  """
  @callback saga_name() :: String.t()

  @doc """
  初期状態を作成する
  """
  @callback initial_state(event :: struct()) :: map()

  @doc """
  Saga のステップを定義する
  """
  @callback steps() :: [atom()]

  @doc """
  イベントを処理する
  """
  @callback handle_event(event :: struct(), state :: map()) ::
              {:ok, new_state :: map()}
              | {:error, reason :: term()}

  @doc """
  ステップを実行する
  """
  @callback execute_step(step :: atom(), state :: map()) ::
              {:ok, commands :: [struct()]}
              | {:error, reason :: term()}

  @doc """
  ステップを補償する（ロールバック）
  """
  @callback compensate_step(step :: atom(), state :: map()) ::
              {:ok, commands :: [struct()]}
              | {:error, reason :: term()}

  @doc """
  ステップがリトライ可能かチェックする
  """
  @callback can_retry_step?(step :: atom(), error :: term(), state :: map()) :: boolean()

  @doc """
  Saga が完了したかチェックする
  """
  @callback is_completed?(state :: map()) :: boolean()

  @doc """
  Saga が失敗したかチェックする
  """
  @callback is_failed?(state :: map()) :: boolean()

  @doc """
  タイムアウト時間を取得する（ミリ秒）
  """
  @callback timeout() :: non_neg_integer()

  @doc """
  最大リトライ回数を取得する
  """
  @callback max_retries() :: non_neg_integer()

  # オプショナルコールバック
  @optional_callbacks [timeout: 0, max_retries: 0]

  @doc """
  Saga モジュールが必要な関数を実装しているかチェックする
  """
  defmacro __using__(_opts) do
    quote do
      @behaviour Shared.Infrastructure.Saga.SagaDefinition

      # デフォルト実装
      # 5分
      def timeout, do: 300_000
      def max_retries, do: 3

      defoverridable timeout: 0, max_retries: 0
    end
  end
end

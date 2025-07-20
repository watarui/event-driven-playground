defmodule Shared.Behaviours.Saga do
  @moduledoc """
  Saga パターンのインターフェース定義

  分散トランザクションを管理し、
  補償処理を含む長期実行プロセスを定義します。
  """

  alias Shared.Types

  @type saga_id :: Types.saga_id()
  @type saga_state :: Types.saga_state()
  @type command :: Types.command()
  @type event :: Types.event()
  @type step_name :: atom()
  @type error_reason :: Types.error_reason()

  @type step_result :: {:ok, [command()]} | {:error, error_reason()}
  @type compensation_result :: {:ok, [command()]} | {:error, error_reason()}

  @type step_definition :: %{
          name: step_name(),
          timeout: non_neg_integer(),
          compensate_on_timeout: boolean(),
          retry_policy: map() | nil
        }

  @doc """
  Saga の名前を返す
  """
  @callback saga_name() :: String.t()

  @doc """
  初期状態を作成する

  トリガーイベントから Saga の初期状態を構築します。
  """
  @callback initial_state(event()) :: saga_state()

  @doc """
  Saga のステップ定義を返す

  各ステップの実行順序、タイムアウト、リトライポリシーなどを定義。
  """
  @callback steps() :: [step_definition()]

  @doc """
  イベントを処理する

  外部イベントを受け取り、Saga の状態を更新します。
  """
  @callback handle_event(event(), saga_state()) ::
              {:ok, saga_state()} | :ignore | {:error, error_reason()}

  @doc """
  ステップを実行する

  現在のステップで実行すべきコマンドを返します。
  """
  @callback execute_step(step_name(), saga_state()) :: step_result()

  @doc """
  補償ステップを実行する

  失敗時に実行すべき補償コマンドを返します。
  """
  @callback compensate_step(step_name(), saga_state()) :: compensation_result()

  @doc """
  ステップがリトライ可能かチェックする
  """
  @callback can_retry_step?(step_name(), error_reason(), saga_state()) :: boolean()

  @doc """
  Saga が完了したかチェックする
  """
  @callback is_completed?(saga_state()) :: boolean()

  @doc """
  Saga が失敗したかチェックする
  """
  @callback is_failed?(saga_state()) :: boolean()

  @doc """
  タイムアウト時のハンドリング

  デフォルトでは補償処理を開始しますが、
  カスタマイズ可能です。
  """
  @callback handle_timeout(step_name(), saga_state()) ::
              {:compensate, saga_state()} | {:retry, saga_state()} | {:fail, saga_state()}

  @optional_callbacks [handle_timeout: 2]
end

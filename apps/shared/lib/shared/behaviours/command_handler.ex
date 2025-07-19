defmodule Shared.Behaviours.CommandHandler do
  @moduledoc """
  コマンドハンドラーのインターフェース定義
  
  CQRS パターンのコマンド側の処理を定義します。
  """
  
  alias Shared.Types
  
  @type command :: Types.command()
  @type event :: Types.event()
  @type aggregate :: struct()
  @type result :: Types.result()
  
  @doc """
  サポートするコマンドタイプを返す
  
  ハンドラーが処理可能なコマンドの型リストを返します。
  """
  @callback supported_commands() :: [module()]
  
  @doc """
  コマンドを処理する
  
  コマンドを受け取り、ビジネスロジックを実行し、
  成功時はイベントを返します。
  """
  @callback handle(command()) :: 
    {:ok, event() | [event()]} | {:error, Types.error_reason()}
    
  @doc """
  コマンドをバリデートする
  
  コマンドの事前条件をチェックします。
  デフォルトでは changeset のバリデーションを実行。
  """
  @callback validate_command(command()) ::
    :ok | {:error, Types.validation_errors()}
    
  @doc """
  コマンドの実行権限をチェックする
  
  ユーザーコンテキストに基づいて権限をチェックします。
  """
  @callback authorize(command(), Types.user_context()) ::
    :ok | {:error, :unauthorized}
    
  @doc """
  コマンド実行前のフック
  
  ロギング、メトリクス収集などに使用。
  """
  @callback before_handle(command()) :: command()
  
  @doc """
  コマンド実行後のフック
  
  通知、副作用の実行などに使用。
  """
  @callback after_handle(command(), result()) :: result()
  
  @optional_callbacks [
    validate_command: 1,
    authorize: 2,
    before_handle: 1,
    after_handle: 2
  ]
end
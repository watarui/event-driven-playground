defmodule Shared.Behaviours.Repository do
  @moduledoc """
  リポジトリパターンのインターフェース定義
  
  アグリゲートの永続化とロードを抽象化します。
  """
  
  alias Shared.Types
  
  @type aggregate :: struct()
  @type aggregate_id :: Types.aggregate_id()
  @type version :: Types.event_version()
  @type result :: Types.result()
  
  @doc """
  ID でアグリゲートを取得する
  """
  @callback get(aggregate_id()) :: 
    {:ok, aggregate()} | {:error, :not_found | term()}
    
  @doc """
  アグリゲートを保存する
  
  楽観的ロックをサポートし、バージョン競合を検出します。
  """
  @callback save(aggregate()) :: 
    {:ok, aggregate()} | {:error, :version_conflict | term()}
    
  @doc """
  アグリゲートが存在するかチェックする
  """
  @callback exists?(aggregate_id()) :: boolean()
  
  @doc """
  条件に基づいてアグリゲートを検索する
  
  Note: イベントソーシングでは通常使用しないが、
  特定のユースケースのために定義。
  """
  @callback find_by(keyword()) :: 
    {:ok, [aggregate()]} | {:error, term()}
    
  @doc """
  アグリゲートを削除する
  
  論理削除の場合は削除イベントを追加。
  物理削除の場合はストリームごと削除。
  """
  @callback delete(aggregate_id()) :: 
    :ok | {:error, :not_found | term()}
    
  @doc """
  アグリゲートの総数を取得する
  """
  @callback count(keyword()) :: 
    {:ok, non_neg_integer()} | {:error, term()}
    
  @doc """
  トランザクション内で操作を実行する
  """
  @callback transaction((-> result())) :: result()
  
  @doc """
  すべてのアグリゲートを取得する（テスト用）
  """
  @callback all(keyword()) :: 
    {:ok, [aggregate()]} | {:error, term()}
end
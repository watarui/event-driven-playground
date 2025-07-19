defmodule Shared.Behaviours.EventStore do
  @moduledoc """
  イベントストアのインターフェース定義
  
  イベントソーシングパターンを実装するために必要な
  基本的な操作を定義します。
  """
  
  alias Shared.Types
  
  @type stream_id :: Types.aggregate_id()
  @type event :: Types.event()
  @type version :: Types.event_version()
  @type metadata :: Types.event_metadata()
  @type subscription :: reference()
  
  @doc """
  イベントをストリームに追加する
  
  期待されるバージョンとの整合性をチェックし、
  競合がある場合はエラーを返します。
  """
  @callback append_events(stream_id(), [event()], version(), metadata()) :: 
    {:ok, version()} | {:error, :version_conflict | term()}
    
  @doc """
  ストリームからイベントを読み取る
  
  指定されたバージョン以降のすべてのイベントを返します。
  """
  @callback read_stream(stream_id(), version()) :: 
    {:ok, [event()]} | {:error, :stream_not_found | term()}
    
  @doc """
  すべてのイベントを読み取る（デバッグ用）
  """
  @callback read_all_events(limit :: non_neg_integer()) ::
    {:ok, [event()]} | {:error, term()}
    
  @doc """
  ストリームのイベントを購読する
  
  新しいイベントが追加されるたびに通知を受け取ります。
  """
  @callback subscribe(stream_id() | :all, pid()) :: 
    {:ok, subscription()} | {:error, term()}
    
  @doc """
  購読を解除する
  """
  @callback unsubscribe(subscription()) :: :ok | {:error, term()}
  
  @doc """
  古いイベントをアーカイブする
  """
  @callback archive_events(days :: non_neg_integer()) ::
    {:ok, count :: non_neg_integer()} | {:error, term()}
    
  @doc """
  ストリームの現在のバージョンを取得する
  """
  @callback get_stream_version(stream_id()) ::
    {:ok, version()} | {:error, :stream_not_found}
    
  @doc """
  イベントストアのヘルスチェック
  """
  @callback health_check() :: :ok | {:error, term()}
end
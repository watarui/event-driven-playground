defmodule Shared.Behaviours.EventBus do
  @moduledoc """
  イベントバスのインターフェース定義
  
  イベント駆動アーキテクチャのためのパブリッシュ/サブスクライブ
  メカニズムを定義します。
  """
  
  alias Shared.Types
  
  @type event :: Types.event()
  @type event_type :: Types.event_type()
  @type subscriber :: pid()
  @type subscription :: reference()
  @type topic :: String.t() | atom()
  
  @doc """
  イベントバスを開始する
  
  実装に応じた child_spec を返します。
  """
  @callback child_spec(keyword()) :: Supervisor.child_spec()
  
  @doc """
  イベントを発行する
  
  特定のイベントタイプのチャンネルに発行します。
  """
  @callback publish(event_type(), event()) :: :ok | {:error, term()}
  
  @doc """
  複数のイベントを一括発行する
  """
  @callback publish_batch([event()]) :: :ok | {:error, term()}
  
  @doc """
  特定のイベントタイプを購読する
  """
  @callback subscribe(event_type()) :: :ok | {:error, term()}
  
  @doc """
  すべてのイベントを購読する
  """
  @callback subscribe_all() :: :ok | {:error, term()}
  
  @doc """
  購読を解除する
  """
  @callback unsubscribe(event_type() | :all) :: :ok
  
  @doc """
  カスタムトピックにメッセージを発行する
  
  コマンドやレスポンスなど、イベント以外のメッセージング用。
  """
  @callback publish_raw(topic(), any()) :: :ok | {:error, term()}
  
  @doc """
  カスタムトピックを購読する
  """
  @callback subscribe_raw(topic()) :: :ok | {:error, term()}
  
  @doc """
  カスタムトピックの購読を解除する
  """
  @callback unsubscribe_raw(topic()) :: :ok
  
  @doc """
  現在の購読者数を取得する
  """
  @callback subscriber_count(event_type() | topic()) :: 
    {:ok, non_neg_integer()} | {:error, term()}
    
  @doc """
  ヘルスチェック
  """
  @callback health_check() :: :ok | {:error, term()}
  
  @optional_callbacks [
    publish_batch: 1,
    subscriber_count: 1,
    health_check: 0
  ]
end
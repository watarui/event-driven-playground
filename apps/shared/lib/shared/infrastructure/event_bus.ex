defmodule Shared.Infrastructure.EventBus do
  @moduledoc """
  統一されたイベントバス実装
  ローカル通信には Phoenix.PubSub を使用
  サービス間通信には Google Cloud Pub/Sub を使用
  """

  alias Shared.Telemetry.Tracing.MessagePropagator
  alias Shared.Infrastructure.PubSub.CloudPubSubClient
  require Logger

  @pubsub_name :event_bus_pubsub

  @doc """
  イベントを発行する
  """
  @spec publish(atom(), any()) :: :ok
  def publish(event_type, event) do
    Logger.debug(
      "EventBus publishing to topic: events:#{event_type}, event: #{inspect(event, limit: :infinity)}"
    )

    # ローカルの Phoenix.PubSub でブロードキャスト
    Phoenix.PubSub.broadcast(@pubsub_name, "events:#{event_type}", {:event, event})
    Phoenix.PubSub.broadcast(@pubsub_name, "events:all", {:event, event_type, event})
    
    # 本番環境では Google Cloud Pub/Sub にも発行
    if use_cloud_pubsub?() do
      CloudPubSubClient.publish("events-#{event_type}", event)
    end
    
    :ok
  end

  @doc """
  特定のイベントタイプを購読する
  """
  @spec subscribe(atom()) :: :ok | {:error, term()}
  def subscribe(event_type) do
    Logger.info("EventBus subscribing to topic: events:#{event_type}")
    Phoenix.PubSub.subscribe(@pubsub_name, "events:#{event_type}")
  end

  @doc """
  すべてのイベントを購読する
  """
  @spec subscribe_all() :: :ok | {:error, term()}
  def subscribe_all do
    Phoenix.PubSub.subscribe(@pubsub_name, "events:all")
  end

  @doc """
  購読を解除する
  """
  @spec unsubscribe(atom()) :: :ok
  def unsubscribe(event_type) do
    Phoenix.PubSub.unsubscribe(@pubsub_name, "events:#{event_type}")
  end

  @doc """
  すべてのイベントの購読を解除する
  """
  @spec unsubscribe_all() :: :ok
  def unsubscribe_all do
    Phoenix.PubSub.unsubscribe(@pubsub_name, "events:all")
  end

  @doc """
  プレフィックスなしでメッセージを発行する（コマンド/レスポンス用）
  """
  @spec publish_raw(atom() | String.t(), any()) :: :ok
  def publish_raw(topic, message) do
    Logger.debug(
      "EventBus publishing raw to topic: #{topic}, message: #{inspect(message, limit: :infinity)}"
    )

    # ローカルの Phoenix.PubSub でブロードキャスト
    Phoenix.PubSub.broadcast(@pubsub_name, to_string(topic), {:event, message})
    
    # 本番環境では Google Cloud Pub/Sub にも発行
    if use_cloud_pubsub?() do
      CloudPubSubClient.publish(to_string(topic), message)
    end
    
    :ok
  end

  @doc """
  プレフィックスなしでトピックを購読する（コマンド/レスポンス用）
  """
  @spec subscribe_raw(atom() | String.t()) :: :ok | {:error, term()}
  def subscribe_raw(topic) do
    Logger.info("EventBus subscribing raw to topic: #{topic}")
    Phoenix.PubSub.subscribe(@pubsub_name, to_string(topic))
  end

  @doc """
  プレフィックスなしで購読を解除する
  """
  @spec unsubscribe_raw(atom() | String.t()) :: :ok
  def unsubscribe_raw(topic) do
    Phoenix.PubSub.unsubscribe(@pubsub_name, to_string(topic))
  end

  @doc """
  イベントオブジェクトからイベントタイプを取得して発行する
  """
  @spec publish_event(struct()) :: :ok
  def publish_event(event) do
    # トレーシングコンテキストを注入
    MessagePropagator.wrap_event_publish(event, fn ev ->
      event_type = ev.__struct__.event_type()
      publish(event_type, ev)
    end)
  end

  @doc """
  複数のイベントを発行する
  """
  @spec publish_all([struct()]) :: :ok
  def publish_all(events) do
    Enum.each(events, &publish_event/1)
    :ok
  end

  # Private functions

  defp use_cloud_pubsub? do
    System.get_env("MIX_ENV") == "prod" && 
    System.get_env("GOOGLE_CLOUD_PROJECT") != nil &&
    System.get_env("FORCE_LOCAL_PUBSUB") != "true"
  end
end

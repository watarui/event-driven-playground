defmodule Shared.Infrastructure.EventBus do
  @moduledoc """
  統一されたイベントバス実装
  環境に応じて PG2 または Google Cloud Pub/Sub を自動的に選択
  """

  alias Shared.Telemetry.Tracing.MessagePropagator
  require Logger

  @pubsub_name :event_bus_pubsub

  @doc """
  イベントバスを開始する
  """
  def child_spec(opts \\ []) do
    adapter = get_adapter()
    Logger.info("EventBus.child_spec called with adapter: #{inspect(adapter)}")

    # GoogleCloudAdapter の場合は独自の child_spec を使用
    if adapter == Shared.Infrastructure.PubSub.GoogleCloudAdapter do
      Logger.info("EventBus: Using GoogleCloudAdapter child_spec")
      adapter.child_spec([{:name, @pubsub_name}] ++ opts)
    else
      Logger.info("EventBus: Using Phoenix.PubSub with adapter: #{inspect(adapter)}")
      Phoenix.PubSub.child_spec([{:name, @pubsub_name}, {:adapter, adapter}] ++ opts)
    end
  end

  @doc """
  イベントを発行する
  """
  @spec publish(atom(), any()) :: :ok
  def publish(event_type, event) do
    Logger.debug(
      "EventBus publishing to topic: events:#{event_type}, event: #{inspect(event, limit: :infinity)}"
    )

    # 環境に応じてlocal_broadcastかbroadcastを使い分ける
    if use_local_broadcast?() do
      Phoenix.PubSub.local_broadcast(@pubsub_name, "events:#{event_type}", {:event, event})
      Phoenix.PubSub.local_broadcast(@pubsub_name, "events:all", {:event, event_type, event})
    end

    Phoenix.PubSub.broadcast(@pubsub_name, "events:#{event_type}", {:event, event})
    Phoenix.PubSub.broadcast(@pubsub_name, "events:all", {:event, event_type, event})
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

    Phoenix.PubSub.broadcast(@pubsub_name, to_string(topic), {:event, message})
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
    case MessagePropagator.wrap_event_publish(event, topic: "events") do
      {:ok, updated_event} ->
        event_type = updated_event.__struct__.event_type()
        publish(event_type, updated_event)

      _ ->
        # フォールバック
        event_type = event.__struct__.event_type()
        publish(event_type, event)
    end
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

  defp get_adapter do
    cond do
      # 一時的に本番環境でも PG2 を使用してテスト
      System.get_env("FORCE_LOCAL_PUBSUB") == "true" ->
        Logger.info("EventBus: Forcing Phoenix.PubSub.PG2 (FORCE_LOCAL_PUBSUB is set)")
        Phoenix.PubSub.PG2

      System.get_env("GOOGLE_CLOUD_PROJECT") && System.get_env("FORCE_LOCAL_PUBSUB") != "true" ->
        Logger.info("EventBus: Using GoogleCloudAdapter (GOOGLE_CLOUD_PROJECT is set)")
        Shared.Infrastructure.PubSub.GoogleCloudAdapter

      System.get_env("MIX_ENV") == "prod" && System.get_env("FORCE_LOCAL_PUBSUB") != "true" ->
        Logger.info("EventBus: Using GoogleCloudAdapter (MIX_ENV is prod)")
        Shared.Infrastructure.PubSub.GoogleCloudAdapter

      true ->
        Logger.info("EventBus: Using Phoenix.PubSub.PG2 (local development)")
        Phoenix.PubSub.PG2
    end
  end

  defp use_local_broadcast? do
    # PG2アダプターを使用している場合のみlocal_broadcastを使用
    get_adapter() == Phoenix.PubSub.PG2
  end
end

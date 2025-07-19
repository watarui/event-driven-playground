defmodule ClientService.PubSubBroadcaster do
  @moduledoc """
  PubSub メッセージをキャッシュし、GraphQL サブスクリプション経由で配信する
  """
  use GenServer
  alias Absinthe.Subscription
  require Logger

  @max_messages 1000
  # 1分
  @topic_stats_interval 60_000

  defstruct messages: [], topic_stats: %{}

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def broadcast_message(topic, message_type, payload, source_service \\ nil) do
    message = %{
      id: Ecto.UUID.generate(),
      topic: topic,
      message_type: message_type,
      payload: payload,
      timestamp: DateTime.utc_now(),
      source_service: source_service
    }

    GenServer.cast(__MODULE__, {:broadcast_message, message})
    message
  end

  def get_recent_messages(limit \\ 100) do
    GenServer.call(__MODULE__, {:get_recent_messages, limit})
  end

  def get_topic_stats do
    GenServer.call(__MODULE__, :get_topic_stats)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # PubSub トピックの購読
    :ok = Phoenix.PubSub.subscribe(ClientService.PubSub, "events:*")
    :ok = Phoenix.PubSub.subscribe(ClientService.PubSub, "commands:*")
    :ok = Phoenix.PubSub.subscribe(ClientService.PubSub, "queries:*")
    :ok = Phoenix.PubSub.subscribe(ClientService.PubSub, "sagas:*")

    # 統計更新タイマー
    Process.send_after(self(), :update_stats, @topic_stats_interval)

    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_cast({:broadcast_message, message}, state) do
    # メッセージをキャッシュに追加
    messages = [message | state.messages] |> Enum.take(@max_messages)

    # GraphQL サブスクリプションで配信
    try do
      Subscription.publish(
        ClientServiceWeb.Endpoint,
        message,
        pubsub_stream: "pubsub:#{message.topic}"
      )

      Subscription.publish(
        ClientServiceWeb.Endpoint,
        message,
        pubsub_stream: "pubsub:*"
      )
    rescue
      error ->
        # 起動時やテスト時にエンドポイントが準備できていない場合はログのみ
        require Logger
        Logger.debug("Failed to publish to subscription: #{inspect(error)}")
    end

    # トピック統計を更新
    topic_stats = update_topic_stats(state.topic_stats, message)

    {:noreply, %{state | messages: messages, topic_stats: topic_stats}}
  end

  @impl true
  def handle_call({:get_recent_messages, limit}, _from, state) do
    messages = Enum.take(state.messages, limit)
    {:reply, messages, state}
  end

  @impl true
  def handle_call(:get_topic_stats, _from, state) do
    stats =
      state.topic_stats
      |> Enum.map(fn {topic, data} ->
        %{
          topic: topic,
          message_count: data.count,
          messages_per_minute: calculate_rate(data),
          last_message_at: data.last_message_at
        }
      end)
      |> Enum.sort_by(& &1.message_count, :desc)

    {:reply, stats, state}
  end

  @impl true
  def handle_info({:event_published, event}, state) do
    # EventStore からのイベントを PubSub メッセージとして配信
    broadcast_message(
      "events:#{event.aggregate_type}",
      event.event_type,
      event.event_data,
      "event_store"
    )

    # イベントストリームの GraphQL サブスクリプションにも配信
    try do
      Subscription.publish(
        ClientServiceWeb.Endpoint,
        event,
        event_stream: "events:#{event.aggregate_type}"
      )

      Subscription.publish(
        ClientServiceWeb.Endpoint,
        event,
        event_stream: "events:*"
      )
    rescue
      error ->
        Logger.debug("Failed to publish event to subscription: #{inspect(error)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:saga_update, saga}, state) do
    # Saga 更新を配信
    broadcast_message(
      "sagas:#{saga.saga_type}",
      "saga_#{saga.status}",
      %{saga_id: saga.id, state: saga.state},
      "saga_coordinator"
    )

    # Saga サブスクリプションにも配信
    try do
      Subscription.publish(
        ClientServiceWeb.Endpoint,
        saga,
        saga_updates: "sagas:#{saga.saga_type}"
      )

      Subscription.publish(
        ClientServiceWeb.Endpoint,
        saga,
        saga_updates: "sagas:*"
      )
    rescue
      error ->
        Logger.debug("Failed to publish saga to subscription: #{inspect(error)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(:update_stats, state) do
    # 定期的に統計を更新
    stats = calculate_dashboard_stats(state)

    try do
      Subscription.publish(
        ClientServiceWeb.Endpoint,
        stats,
        dashboard_stats_stream: "dashboard:stats"
      )
    rescue
      error ->
        Logger.debug("Failed to publish stats to subscription: #{inspect(error)}")
    end

    Process.send_after(self(), :update_stats, @topic_stats_interval)
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private functions

  defp update_topic_stats(stats, message) do
    topic_data =
      Map.get(stats, message.topic, %{
        count: 0,
        last_message_at: nil,
        messages_per_interval: []
      })

    now = DateTime.utc_now()

    # 時間窓内のメッセージカウントを更新
    messages_per_interval =
      [{now, 1} | topic_data.messages_per_interval]
      |> Enum.filter(fn {time, _} ->
        # 5分間のウィンドウ
        DateTime.diff(now, time) <= 300
      end)

    Map.put(stats, message.topic, %{
      count: topic_data.count + 1,
      last_message_at: now,
      messages_per_interval: messages_per_interval
    })
  end

  defp calculate_rate(topic_data) do
    case topic_data.messages_per_interval do
      [] ->
        0.0

      messages ->
        # 1分あたりのメッセージ数を計算
        count = Enum.reduce(messages, 0, fn {_, count}, acc -> acc + count end)
        # 5分間の平均
        count / 5.0
    end
  end

  defp calculate_dashboard_stats(_state) do
    # TODO: 実際の統計を計算
    %{
      total_events: 0,
      events_per_minute: 0.0,
      active_sagas: 0,
      total_commands: 0,
      total_queries: 0,
      system_health: "healthy",
      error_rate: 0.0,
      average_latency_ms: 0
    }
  end
end

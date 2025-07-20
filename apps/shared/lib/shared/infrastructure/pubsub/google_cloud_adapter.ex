defmodule Shared.Infrastructure.PubSub.GoogleCloudAdapter do
  @moduledoc """
  Google Cloud Pub/Sub アダプター
  Phoenix.PubSub 互換のインターフェースを提供
  """
  use GenServer
  require Logger

  alias GoogleApi.PubSub.V1.Api.Projects
  alias GoogleApi.PubSub.V1.Model.{PublishRequest, PubsubMessage, PullRequest, AcknowledgeRequest}
  alias GoogleApi.PubSub.V1.Connection

  @behaviour Phoenix.PubSub.Adapter

  # クライアント状態
  defmodule State do
    defstruct [
      :project_id,
      :connection,
      :subscriptions,
      :topic_cache,
      :subscription_workers
    ]
  end

  @doc """
  アダプターの子プロセス仕様
  """
  @impl true
  def child_spec(opts) do
    name = opts[:name] || __MODULE__

    %{
      id: name,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end

  @doc """
  アダプターを開始
  """
  def start_link(opts) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl GenServer
  def init(opts) do
    project_id = get_project_id(opts)

    # Google Cloud 認証情報を設定
    connection = Connection.new()

    state = %State{
      project_id: project_id,
      connection: connection,
      subscriptions: %{},
      topic_cache: %{},
      subscription_workers: %{}
    }

    {:ok, state}
  end

  # Phoenix.PubSub.Adapter callbacks

  @impl Phoenix.PubSub.Adapter
  def node_name(_adapter_name), do: node()

  @impl Phoenix.PubSub.Adapter
  def broadcast(adapter_name, topic, message, dispatcher) do
    GenServer.call(adapter_name, {:broadcast, topic, message, dispatcher})
  end

  @impl Phoenix.PubSub.Adapter
  def direct_broadcast(adapter_name, node_name, topic, message, dispatcher) do
    # Cloud Pub/Sub では全ノードに配信されるため、通常の broadcast と同じ
    broadcast(adapter_name, topic, message, dispatcher)
  end

  # GenServer callbacks

  @impl GenServer
  def handle_call({:broadcast, topic, message, _dispatcher}, _from, state) do
    result = publish_message(topic, message, state)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:subscribe, pid, topic}, _from, state) do
    {result, new_state} = subscribe_to_topic(pid, topic, state)
    {:reply, result, new_state}
  end

  @impl GenServer
  def handle_call({:unsubscribe, pid, topic}, _from, state) do
    new_state = unsubscribe_from_topic(pid, topic, state)
    {:reply, :ok, new_state}
  end

  # 内部関数

  defp get_project_id(opts) do
    opts[:project_id] ||
      System.get_env("GOOGLE_CLOUD_PROJECT") ||
      raise "Google Cloud project ID not configured"
  end

  defp publish_message(topic, message, state) do
    topic_name = format_topic_name(topic, state.project_id)

    # メッセージをシリアライズ
    encoded_message = encode_message(message)

    pubsub_message = %PubsubMessage{
      data: Base.encode64(encoded_message),
      attributes: %{
        "content_type" => "application/x-erlang-binary",
        "source_node" => to_string(node())
      }
    }

    request = %PublishRequest{
      messages: [pubsub_message]
    }

    case Projects.pubsub_projects_topics_publish(
           state.connection,
           topic_name,
           body: request
         ) do
      {:ok, _response} ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to publish to Pub/Sub: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp subscribe_to_topic(pid, topic, state) do
    subscription_name = format_subscription_name(topic, state.project_id)
    topic_name = format_topic_name(topic, state.project_id)

    # サブスクリプションが存在しない場合は作成
    ensure_subscription_exists(subscription_name, topic_name, state)

    # ワーカーが存在しない場合は開始
    worker_key = {topic, subscription_name}

    new_state =
      if Map.has_key?(state.subscription_workers, worker_key) do
        state
      else
        {:ok, worker_pid} = start_subscription_worker(subscription_name, topic, state)

        %{
          state
          | subscription_workers: Map.put(state.subscription_workers, worker_key, worker_pid)
        }
      end

    # PID を購読者リストに追加
    subscribers = Map.get(new_state.subscriptions, topic, [])
    new_subscribers = [pid | subscribers] |> Enum.uniq()

    final_state = %{
      new_state
      | subscriptions: Map.put(new_state.subscriptions, topic, new_subscribers)
    }

    # プロセス監視
    Process.monitor(pid)

    {:ok, final_state}
  end

  defp unsubscribe_from_topic(pid, topic, state) do
    subscribers = Map.get(state.subscriptions, topic, [])
    new_subscribers = Enum.reject(subscribers, &(&1 == pid))

    if Enum.empty?(new_subscribers) do
      # 購読者がいなくなったらワーカーを停止
      worker_key = {topic, format_subscription_name(topic, state.project_id)}

      case Map.get(state.subscription_workers, worker_key) do
        nil -> :ok
        worker_pid -> Process.exit(worker_pid, :normal)
      end

      %{
        state
        | subscriptions: Map.delete(state.subscriptions, topic),
          subscription_workers: Map.delete(state.subscription_workers, worker_key)
      }
    else
      %{state | subscriptions: Map.put(state.subscriptions, topic, new_subscribers)}
    end
  end

  defp ensure_subscription_exists(subscription_name, topic_name, state) do
    case Projects.pubsub_projects_subscriptions_get(state.connection, subscription_name) do
      {:ok, _} ->
        :ok

      {:error, _} ->
        # まずトピックが存在するか確認
        ensure_topic_exists(topic_name, state)

        # サブスクリプションを作成
        body = %{
          topic: topic_name,
          ackDeadlineSeconds: 30,
          messageRetentionDuration: "600s",
          retryPolicy: %{
            minimumBackoff: "10s",
            maximumBackoff: "300s"
          }
        }

        Projects.pubsub_projects_subscriptions_create(
          state.connection,
          subscription_name,
          body: body
        )
    end
  end

  defp ensure_topic_exists(topic_name, state) do
    case Projects.pubsub_projects_topics_get(state.connection, topic_name) do
      {:ok, _} ->
        :ok

      {:error, _} ->
        # トピックを作成
        Projects.pubsub_projects_topics_create(
          state.connection,
          topic_name,
          body: %{}
        )
    end
  end

  defp start_subscription_worker(subscription_name, topic, state) do
    Task.start_link(fn ->
      pull_loop(subscription_name, topic, state)
    end)
  end

  defp pull_loop(subscription_name, topic, state) do
    request = %PullRequest{
      maxMessages: 100,
      returnImmediately: false
    }

    case Projects.pubsub_projects_subscriptions_pull(
           state.connection,
           subscription_name,
           body: request
         ) do
      {:ok, %{receivedMessages: messages}} when is_list(messages) ->
        process_messages(messages, topic, subscription_name, state)

      {:error, reason} ->
        Logger.error("Failed to pull messages: #{inspect(reason)}")
        Process.sleep(5000)
    end

    pull_loop(subscription_name, topic, state)
  end

  defp process_messages([], _topic, _subscription_name, _state), do: :ok

  defp process_messages(messages, topic, subscription_name, state) do
    ack_ids = Enum.map(messages, & &1.ackId)

    # メッセージを処理
    Enum.each(messages, fn msg ->
      case decode_message(msg.message.data) do
        {:ok, decoded_message} ->
          dispatch_to_subscribers(topic, decoded_message, state)

        {:error, reason} ->
          Logger.error("Failed to decode message: #{inspect(reason)}")
      end
    end)

    # ACK を送信
    ack_request = %AcknowledgeRequest{ackIds: ack_ids}

    Projects.pubsub_projects_subscriptions_acknowledge(
      state.connection,
      subscription_name,
      body: ack_request
    )
  end

  defp dispatch_to_subscribers(topic, message, state) do
    subscribers = Map.get(state.subscriptions, topic, [])

    Enum.each(subscribers, fn pid ->
      if Process.alive?(pid) do
        send(pid, message)
      end
    end)
  end

  defp encode_message(message) do
    :erlang.term_to_binary(message)
  end

  defp decode_message(data) do
    try do
      decoded = Base.decode64!(data)
      {:ok, :erlang.binary_to_term(decoded)}
    rescue
      e -> {:error, e}
    end
  end

  defp format_topic_name(topic, project_id) do
    environment = System.get_env("MIX_ENV", "dev")
    "projects/#{project_id}/topics/#{topic}-#{environment}"
  end

  defp format_subscription_name(topic, project_id) do
    environment = System.get_env("MIX_ENV", "dev")
    node_name = node() |> to_string() |> String.replace("@", "-")
    "projects/#{project_id}/subscriptions/#{topic}-#{node_name}-#{environment}"
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # プロセスが終了したら全トピックから購読解除
    new_subscriptions =
      Enum.reduce(state.subscriptions, %{}, fn {topic, subscribers}, acc ->
        new_subscribers = Enum.reject(subscribers, &(&1 == pid))

        if Enum.empty?(new_subscribers) do
          acc
        else
          Map.put(acc, topic, new_subscribers)
        end
      end)

    {:noreply, %{state | subscriptions: new_subscriptions}}
  end
end

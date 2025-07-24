defmodule Shared.Infrastructure.PubSub.CloudPubSubClient do
  @moduledoc """
  Google Cloud Pub/Sub の直接クライアント
  サービス間通信に使用
  """
  use GenServer
  require Logger

  alias GoogleApi.PubSub.V1.Api.Projects
  alias GoogleApi.PubSub.V1.Model.{PublishRequest, PubsubMessage, PullRequest, AcknowledgeRequest}
  alias GoogleApi.PubSub.V1.Connection

  defmodule State do
    defstruct [
      :project_id,
      :connection,
      :subscriptions,
      :subscription_workers
    ]
  end

  def start_link(opts) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def child_spec(opts) do
    %{
      id: opts[:name] || __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker
    }
  end

  @doc """
  メッセージを発行する
  """
  def publish(topic, message) do
    GenServer.call(__MODULE__, {:publish, topic, message})
  end

  @doc """
  トピックを購読する
  """
  def subscribe(topic, handler_module) do
    GenServer.call(__MODULE__, {:subscribe, topic, handler_module})
  end

  @doc """
  購読を解除する
  """
  def unsubscribe(topic) do
    GenServer.call(__MODULE__, {:unsubscribe, topic})
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    Logger.info("CloudPubSubClient: Initializing")

    project_id = get_project_id(opts)
    Logger.info("CloudPubSubClient: Using project_id: #{project_id}")

    # 本番環境でのみ Google Cloud Pub/Sub を使用
    if should_use_cloud_pubsub?() do
      connection = create_connection()
      
      state = %State{
        project_id: project_id,
        connection: connection,
        subscriptions: %{},
        subscription_workers: %{}
      }

      {:ok, state}
    else
      # 開発環境では初期化しない
      {:ok, %State{}}
    end
  end

  @impl true
  def handle_call({:publish, topic, message}, _from, state) do
    if should_use_cloud_pubsub?() and state.connection do
      result = do_publish(topic, message, state)
      {:reply, result, state}
    else
      # 開発環境では何もしない
      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:subscribe, topic, handler_module}, _from, state) do
    if should_use_cloud_pubsub?() and state.connection do
      {result, new_state} = do_subscribe(topic, handler_module, state)
      {:reply, result, new_state}
    else
      # 開発環境では何もしない
      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:unsubscribe, topic}, _from, state) do
    if should_use_cloud_pubsub?() and state.connection do
      new_state = do_unsubscribe(topic, state)
      {:reply, :ok, new_state}
    else
      {:reply, :ok, state}
    end
  end

  # Private functions

  defp should_use_cloud_pubsub? do
    System.get_env("MIX_ENV") == "prod" && 
    System.get_env("GOOGLE_CLOUD_PROJECT") != nil &&
    System.get_env("FORCE_LOCAL_PUBSUB") != "true"
  end

  defp get_project_id(opts) do
    opts[:project_id] ||
      System.get_env("GOOGLE_CLOUD_PROJECT") ||
      raise "Google Cloud project ID not configured"
  end

  defp create_connection do
    try do
      Logger.info("CloudPubSubClient: Fetching auth token from Goth")
      case Goth.fetch(Shared.Goth) do
        {:ok, %{token: token}} ->
          Logger.info("CloudPubSubClient: Successfully fetched auth token")
          Connection.new(token)

        {:error, reason} ->
          Logger.error("CloudPubSubClient: Failed to fetch auth token: #{inspect(reason)}")
          nil
      end
    rescue
      e ->
        Logger.error("CloudPubSubClient: Failed to create connection: #{inspect(e)}")
        nil
    end
  end

  defp do_publish(topic, message, state) do
    topic_name = format_topic_name(topic, state.project_id)
    
    # メッセージをシリアライズ
    encoded_message = :erlang.term_to_binary(message)
    
    pubsub_message = %PubsubMessage{
      data: Base.encode64(encoded_message),
      attributes: %{
        "content_type" => "application/x-erlang-binary",
        "source_node" => to_string(node()),
        "timestamp" => DateTime.to_iso8601(DateTime.utc_now())
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
        Logger.debug("CloudPubSubClient: Published to #{topic_name}")
        :ok

      {:error, reason} ->
        Logger.error("CloudPubSubClient: Failed to publish to #{topic_name}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp do_subscribe(topic, handler_module, state) do
    subscription_name = format_subscription_name(topic, state.project_id)
    topic_name = format_topic_name(topic, state.project_id)
    
    # サブスクリプションが存在しない場合は作成
    ensure_subscription_exists(subscription_name, topic_name, state)
    
    # ワーカーが存在しない場合は開始
    if Map.has_key?(state.subscription_workers, topic) do
      {:ok, state}
    else
      {:ok, worker_pid} = start_subscription_worker(
        subscription_name, 
        topic, 
        handler_module, 
        state
      )
      
      new_state = %{
        state
        | subscription_workers: Map.put(state.subscription_workers, topic, worker_pid),
          subscriptions: Map.put(state.subscriptions, topic, handler_module)
      }
      
      {:ok, new_state}
    end
  end

  defp do_unsubscribe(topic, state) do
    case Map.get(state.subscription_workers, topic) do
      nil -> 
        state
      worker_pid -> 
        Process.exit(worker_pid, :normal)
        %{
          state
          | subscription_workers: Map.delete(state.subscription_workers, topic),
            subscriptions: Map.delete(state.subscriptions, topic)
        }
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

  defp start_subscription_worker(subscription_name, topic, handler_module, state) do
    Task.start_link(fn ->
      pull_loop(subscription_name, topic, handler_module, state)
    end)
  end

  defp pull_loop(subscription_name, topic, handler_module, state) do
    request = %PullRequest{
      maxMessages: 10,
      returnImmediately: false
    }
    
    case Projects.pubsub_projects_subscriptions_pull(
           state.connection,
           subscription_name,
           body: request
         ) do
      {:ok, %{receivedMessages: messages}} when is_list(messages) and length(messages) > 0 ->
        process_messages(messages, topic, handler_module, subscription_name, state)

      {:error, reason} ->
        Logger.error("CloudPubSubClient: Failed to pull messages: #{inspect(reason)}")
        Process.sleep(5000)

      _ ->
        # メッセージがない場合
        Process.sleep(1000)
    end
    
    pull_loop(subscription_name, topic, handler_module, state)
  end

  defp process_messages(messages, topic, handler_module, subscription_name, state) do
    ack_ids = Enum.map(messages, & &1.ackId)
    
    # メッセージを処理
    Enum.each(messages, fn msg ->
      case decode_message(msg.message.data) do
        {:ok, decoded_message} ->
          # ハンドラーモジュールを呼び出す
          try do
            handler_module.handle_cloud_pubsub_message(topic, decoded_message)
          rescue
            e ->
              Logger.error("CloudPubSubClient: Handler error: #{inspect(e)}")
          end

        {:error, reason} ->
          Logger.error("CloudPubSubClient: Failed to decode message: #{inspect(reason)}")
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
    # トピック名に @ が含まれる場合は - に置換（PubSub の制限）
    sanitized_topic = topic |> to_string() |> String.replace("@", "-at-")
    "projects/#{project_id}/topics/#{sanitized_topic}-#{environment}"
  end

  defp format_subscription_name(topic, project_id) do
    environment = System.get_env("MIX_ENV", "dev")
    service_name = System.get_env("SERVICE_NAME", "unknown")
    
    # Terraform で定義されたサブスクリプション名の形式に合わせる
    subscription_name = case {to_string(topic), service_name} do
      {"command-requests", "command-service"} -> "command-service-requests-sub-#{environment}"
      {"query-requests", "query-service"} -> "query-service-requests-sub-#{environment}"
      _ ->
        # その他のトピックの場合は従来の形式
        sanitized_topic = topic |> to_string() |> String.replace("@", "-at-")
        "#{sanitized_topic}-#{service_name}-#{environment}"
    end
    
    "projects/#{project_id}/subscriptions/#{subscription_name}"
  end
end
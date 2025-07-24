defmodule ClientService.Infrastructure.RemoteCommandBus do
  @moduledoc """
  リモートコマンドバス

  PubSub を使用して Command Service にコマンドを送信し、
  レスポンスを非同期で受信します。
  """

  use GenServer

  alias Shared.Config
  alias Shared.Infrastructure.Resilience.CircuitBreaker

  require Logger

  @command_topic :"command-requests"
  @response_timeout 5_000

  # クライアント API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  コマンドを送信してレスポンスを待つ
  """
  def send_command(command) do
    GenServer.call(__MODULE__, {:send_command, command}, @response_timeout + 1_000)
  end

  # サーバーコールバック

  @impl true
  def init(_opts) do
    # レスポンス用のトピックを購読
    # raw メソッドを使用してプレフィックスなしで購読
    # Cloud Run では固定のサービス名を使用
    service_name = System.get_env("SERVICE_NAME", "client_service")
    response_topic = :"command-responses"
    event_bus = Config.event_bus_module()
    event_bus.subscribe_raw(response_topic)

    # 本番環境では Cloud Pub/Sub も購読
    if should_use_cloud_pubsub?() do
      Shared.Infrastructure.PubSub.CloudPubSubClient.subscribe("command-responses", __MODULE__)
    end

    Logger.info(
      "RemoteCommandBus initialized with response_topic: #{response_topic}, using #{inspect(event_bus)}"
    )

    state = %{
      pending_requests: %{},
      response_topic: response_topic,
      event_bus: event_bus
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:send_command, command}, from, state) do
    # リクエスト ID を生成
    request_id = UUID.uuid4()

    Logger.info(
      "RemoteCommandBus sending command: type=#{inspect(command[:command_type])}, request_id=#{request_id}"
    )

    # コマンドメッセージを作成
    message = %{
      request_id: request_id,
      command: command,
      reply_to: to_string(state.response_topic),
      timestamp: DateTime.utc_now()
    }

    Logger.info("Publishing to topic #{@command_topic}, reply_to: #{state.response_topic}")
    Logger.debug("Full message: #{inspect(message, limit: :infinity)}")

    # サーキットブレーカーを通じてコマンドを発行
    case CircuitBreaker.call(:command_bus, fn ->
           state.event_bus.publish_raw(@command_topic, message)
           {:ok, :published}
         end) do
      {:ok, :published} ->
        # ペンディングリクエストに追加
        pending_requests = Map.put(state.pending_requests, request_id, from)

        # タイムアウトタイマーを設定
        Process.send_after(self(), {:timeout, request_id}, @response_timeout)

        {:noreply, %{state | pending_requests: pending_requests}}

      {:error, :circuit_open} ->
        Logger.error("Circuit breaker is open for command bus")
        GenServer.reply(from, {:error, :service_unavailable})
        {:noreply, state}

      {:error, reason} ->
        Logger.error("Failed to publish command: #{inspect(reason)}")
        GenServer.reply(from, {:error, reason})
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:event, response}, state) when is_map(response) do
    Logger.info(
      "RemoteCommandBus received response: request_id=#{inspect(Map.get(response, :request_id))}"
    )

    Logger.debug("Full response: #{inspect(response, limit: :infinity)}")

    case Map.get(state.pending_requests, response.request_id) do
      nil ->
        # 未知のレスポンス（すでにタイムアウトしたか、別のノードへのレスポンス）
        Logger.warning("Received response for unknown request_id: #{response.request_id}")
        {:noreply, state}

      from ->
        # クライアントにレスポンスを返す
        Logger.info("Returning response to client: #{inspect(response.result)}")
        GenServer.reply(from, response.result)

        # ペンディングリクエストから削除
        pending_requests = Map.delete(state.pending_requests, response.request_id)
        {:noreply, %{state | pending_requests: pending_requests}}
    end
  end

  @impl true
  def handle_info({:timeout, request_id}, state) do
    case Map.get(state.pending_requests, request_id) do
      nil ->
        # すでに処理済み
        {:noreply, state}

      from ->
        # タイムアウトエラーを返す
        GenServer.reply(from, {:error, :timeout})

        # ペンディングリクエストから削除
        pending_requests = Map.delete(state.pending_requests, request_id)
        {:noreply, %{state | pending_requests: pending_requests}}
    end
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug(
      "RemoteCommandBus received unexpected message: #{inspect(msg, limit: :infinity)}"
    )

    {:noreply, state}
  end

  @doc """
  Cloud Pub/Sub からのメッセージを処理
  """
  def handle_cloud_pubsub_message(topic, message) do
    Logger.info("RemoteCommandBus received Cloud Pub/Sub message on #{topic}: #{inspect(message)}")
    
    # GenServer にメッセージを転送
    send(__MODULE__, {:event, message})
  end

  defp should_use_cloud_pubsub? do
    System.get_env("MIX_ENV") == "prod" && 
    System.get_env("GOOGLE_CLOUD_PROJECT") != nil &&
    System.get_env("FORCE_LOCAL_PUBSUB") != "true"
  end
end

defmodule ClientService.Infrastructure.RemoteQueryBus do
  @moduledoc """
  リモートクエリバス

  PubSub を使用して Query Service にクエリを送信し、
  レスポンスを非同期で受信します。
  """

  use GenServer

  alias Shared.Config

  require Logger

  @query_topic :queries
  @response_timeout 5_000

  # クライアント API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  クエリを送信してレスポンスを待つ
  """
  def send_query(query) do
    GenServer.call(__MODULE__, {:send_query, query}, @response_timeout + 1_000)
  end

  # サーバーコールバック

  @impl true
  def init(_opts) do
    # レスポンス用のトピックを購読
    # raw メソッドを使用してプレフィックスなしで購読
    response_topic = :"query_responses_#{node()}"
    event_bus = Config.event_bus_module()
    event_bus.subscribe_raw(response_topic)

    state = %{
      pending_requests: %{},
      response_topic: response_topic,
      event_bus: event_bus
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:send_query, query}, from, state) do
    # リクエスト ID を生成
    request_id = UUID.uuid4()

    # クエリメッセージを作成
    message = %{
      request_id: request_id,
      query: query,
      reply_to: state.response_topic,
      timestamp: DateTime.utc_now()
    }

    # クエリを発行（raw メソッドを使用）
    state.event_bus.publish_raw(@query_topic, message)

    # ペンディングリクエストに追加
    pending_requests = Map.put(state.pending_requests, request_id, from)

    # タイムアウトタイマーを設定
    Process.send_after(self(), {:timeout, request_id}, @response_timeout)

    {:noreply, %{state | pending_requests: pending_requests}}
  end

  @impl true
  def handle_info({:event, response}, state) when is_map(response) do
    case Map.get(state.pending_requests, response.request_id) do
      nil ->
        # 未知のレスポンス（すでにタイムアウトしたか、別のノードへのレスポンス）
        {:noreply, state}

      from ->
        # クライアントにレスポンスを返す
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
  def handle_info(_msg, state) do
    {:noreply, state}
  end

end

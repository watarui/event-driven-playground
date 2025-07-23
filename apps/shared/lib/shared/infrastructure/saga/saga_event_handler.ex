defmodule Shared.Infrastructure.Saga.SagaEventHandler do
  @moduledoc """
  Saga 関連のイベントハンドリングを管理

  EventBus から受信したイベントを適切な Saga にルーティングします。
  """

  use GenServer
  require Logger

  alias Shared.Infrastructure.EventBus
  alias Shared.Infrastructure.Saga.SagaExecutor

  # イベントタイプと Saga モジュールのマッピング
  @event_saga_mapping %{
    # OrderSaga が処理するイベント
    "OrderCreated" => CommandService.Domain.Sagas.OrderSaga,
    "InventoryReserved" => :existing_saga,
    "InventoryReservationFailed" => :existing_saga,
    "PaymentProcessed" => :existing_saga,
    "PaymentFailed" => :existing_saga,
    "ShippingArranged" => :existing_saga,
    "ShippingArrangementFailed" => :existing_saga,
    "OrderConfirmed" => :existing_saga
  }

  # State
  defmodule State do
    @moduledoc false
    defstruct [
      :subscriptions
    ]
  end

  # Public API

  @doc """
  SagaEventHandler を開始
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  イベントタイプを Saga に登録
  """
  def register_event_type(event_type, saga_module) do
    GenServer.call(__MODULE__, {:register_event_type, event_type, saga_module})
  end

  @doc """
  登録されているイベントタイプを取得
  """
  def get_registered_events do
    GenServer.call(__MODULE__, :get_registered_events)
  end

  # GenServer Callbacks

  @impl true
  def init(_opts) do
    # イベントバスに登録
    subscriptions = subscribe_to_events()

    state = %State{
      subscriptions: subscriptions
    }

    Logger.info("SagaEventHandler started")
    {:ok, state}
  end

  @impl true
  def handle_call({:register_event_type, event_type, saga_module}, _from, state) do
    # 動的にイベントタイプを登録（実行時の拡張用）
    Process.put({:event_mapping, event_type}, saga_module)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:get_registered_events, _from, state) do
    # 静的マッピングと動的マッピングを結合
    static_events = Map.keys(@event_saga_mapping)

    dynamic_events =
      Process.get_keys()
      |> Enum.filter(fn key ->
        case key do
          {:event_mapping, _} -> true
          _ -> false
        end
      end)
      |> Enum.map(fn {:event_mapping, event_type} -> event_type end)

    all_events = Enum.uniq(static_events ++ dynamic_events)
    {:reply, all_events, state}
  end

  @impl true
  def handle_info({:event, event}, state) do
    handle_saga_event(event)
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("Unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private Functions

  defp subscribe_to_events do
    # Saga が関心のあるイベントトピックに登録
    topics = [
      "order_events",
      "inventory_events",
      "payment_events",
      "shipping_events"
    ]

    Enum.map(topics, fn topic ->
      :ok = EventBus.subscribe(topic)
      topic
    end)
  end

  defp handle_saga_event(event) do
    event_type = extract_event_type(event)

    Logger.debug("Processing event for saga: type=#{event_type}")

    # イベントタイプに基づいて処理を決定
    case get_saga_for_event(event_type) do
      nil ->
        # この EventHandler が処理しないイベント
        :ok

      :existing_saga ->
        # 既存の Saga に転送
        SagaExecutor.handle_event(event)

      saga_module when is_atom(saga_module) ->
        # 新しい Saga を開始
        case should_start_new_saga?(event, saga_module) do
          true ->
            Logger.info(
              "Starting new saga: module=#{inspect(saga_module)}, trigger=#{event_type}"
            )

            SagaExecutor.start_saga(saga_module, event)

          false ->
            # 既存の Saga に転送
            SagaExecutor.handle_event(event)
        end
    end
  rescue
    e ->
      Logger.error("Failed to handle saga event: #{inspect(e)}")
      :error
  end

  defp extract_event_type(event) do
    # イベントの型名を取得
    event.__struct__
    |> Module.split()
    |> List.last()
  end

  defp get_saga_for_event(event_type) do
    # 動的マッピングを優先
    case Process.get({:event_mapping, event_type}) do
      nil -> Map.get(@event_saga_mapping, event_type)
      saga_module -> saga_module
    end
  end

  defp should_start_new_saga?(event, saga_module) do
    # Saga モジュールに問い合わせて、新しい Saga を開始すべきか判断
    if function_exported?(saga_module, :should_start_on_event?, 1) do
      saga_module.should_start_on_event?(event)
    else
      # デフォルトでは、saga_id が含まれていない場合は新規開始
      is_nil(Map.get(event, :saga_id))
    end
  end
end

defmodule Shared.Infrastructure.Saga.SagaDefinition do
  @moduledoc """
  Saga 実装のための追加インターフェース

  Shared.Behaviours.Saga を拡張し、イベントハンドリングに
  必要な追加機能を定義します。
  """

  @doc """
  特定のイベントタイプを処理できるか判断
  """
  @callback can_handle_event?(event_type :: String.t()) :: boolean()

  @doc """
  イベントを受信して新しい Saga を開始すべきか判断
  """
  @callback should_start_on_event?(event :: map()) :: boolean()

  @optional_callbacks [can_handle_event?: 1, should_start_on_event?: 1]

  defmacro __using__(_opts) do
    quote do
      @behaviour Shared.Behaviours.Saga
      @behaviour Shared.Infrastructure.Saga.SagaDefinition

      # デフォルト実装
      def can_handle_event?("OrderCreated"),
        do: __MODULE__ == CommandService.Domain.Sagas.OrderSaga

      def can_handle_event?(_), do: false

      def should_start_on_event?(event) do
        # デフォルトでは saga_id がない場合に新規開始
        is_nil(Map.get(event, :saga_id))
      end

      defoverridable can_handle_event?: 1, should_start_on_event?: 1
    end
  end
end

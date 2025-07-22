defmodule QueryService.Infrastructure.ProjectionManager do
  @moduledoc """
  プロジェクションマネージャー

  - リアルタイムイベント処理（EventBus 購読）
  - プロジェクション再構築機能
  - エラーハンドリングとリトライ
  - 並列処理対応
  """

  use GenServer

  alias Shared.Config
  alias Shared.Infrastructure.Retry.{RetryStrategy, RetryPolicy}
  alias Shared.Infrastructure.DeadLetterQueue

  alias QueryService.Infrastructure.Projections.{
    CategoryProjection,
    ProductProjection,
    OrderProjection
  }

  require Logger

  # バッチ処理設定
  @batch_size 100

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Public API

  @doc """
  特定のプロジェクションを再構築する
  """
  def rebuild_projection(projection_module) do
    GenServer.call(__MODULE__, {:rebuild_projection, projection_module}, :infinity)
  end

  @doc """
  すべてのプロジェクションを再構築する
  """
  def rebuild_all_projections do
    GenServer.call(__MODULE__, :rebuild_all_projections, :infinity)
  end

  @doc """
  プロジェクションの状態を取得する
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    Logger.info("ProjectionManager starting...")

    # EventBusモジュールを選択
    event_bus = Config.event_bus_module()

    state = %{
      projections: %{
        CategoryProjection => %{status: :running, last_error: nil, processed_count: 0},
        ProductProjection => %{status: :running, last_error: nil, processed_count: 0},
        OrderProjection => %{status: :running, last_error: nil, processed_count: 0}
      },
      subscriptions: %{},
      rebuilding: false,
      event_bus: event_bus
    }

    # EventBus に購読
    new_state = subscribe_to_events(state)

    Logger.info(
      "ProjectionManager subscribed to #{map_size(new_state.subscriptions)} event types using #{inspect(event_bus)}"
    )

    {:ok, new_state}
  end

  @impl true
  def handle_call({:rebuild_projection, projection_module}, _from, state) do
    Logger.info("Starting rebuild for projection: #{projection_module}")

    result = do_rebuild_projection(projection_module)

    {:reply, result, state}
  end

  @impl true
  def handle_call(:rebuild_all_projections, _from, state) do
    Logger.info("Starting rebuild for all projections")

    # 一時的に購読を解除
    state = unsubscribe_all(state)

    results =
      Enum.map(Map.keys(state.projections), fn projection_module ->
        {projection_module, do_rebuild_projection(projection_module)}
      end)

    # 購読を再開
    state = subscribe_to_events(state)

    {:reply, {:ok, results}, state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply, state.projections, state}
  end

  @impl true
  def handle_info({:event, event}, state) do
    Logger.debug("ProjectionManager received event: #{inspect(event, limit: :infinity)}")

    # イベントタイプを取得
    event_type = get_event_type(event)

    if event_type do
      Logger.info("Processing event type: #{event_type}")
      # リアルタイムイベント処理
      state = process_realtime_event(event_type, event, state)
      {:noreply, state}
    else
      Logger.warning("Ignoring event without event_type: #{inspect(event)}")
      {:noreply, state}
    end
  end

  defp get_event_type(event) do
    cond do
      # イベント構造体に event_type メソッドがある場合
      is_struct(event) and function_exported?(event.__struct__, :event_type, 0) ->
        String.to_atom(event.__struct__.event_type())

      # event_type フィールドを直接持っている場合
      is_map(event) and Map.has_key?(event, :event_type) ->
        String.to_atom(event.event_type)

      # __struct__ から推測（OrderCreated -> order.created）
      is_struct(event) ->
        event.__struct__
        |> Module.split()
        |> List.last()
        |> Macro.underscore()
        |> String.replace("_", ".")
        |> String.to_atom()

      true ->
        nil
    end
  end

  # Private functions

  defp subscribe_to_events(state) do
    # 各イベントタイプに購読
    event_types = [
      :"category.created",
      :"category.updated",
      :"category.deleted",
      :"product.created",
      :"product.updated",
      :"product.price_changed",
      :"product.deleted",
      :"order.created",
      :"order.payment_completed",
      :"order.shipped",
      :"order.delivered",
      :"order.cancelled",
      # SAGA イベント
      :"inventory.reserved",
      :"inventory.reservation_failed",
      :"payment.processed",
      :"payment.failed",
      :"shipping.arranged",
      :"shipping.arrangement_failed",
      :"order.confirmed"
    ]

    subscriptions =
      Enum.reduce(event_types, %{}, fn event_type, acc ->
        :ok = state.event_bus.subscribe(event_type)
        Map.put(acc, Atom.to_string(event_type), event_type)
      end)

    %{state | subscriptions: subscriptions}
  end

  defp unsubscribe_all(state) do
    Enum.each(state.subscriptions, fn {_event_type, subscription} ->
      state.event_bus.unsubscribe(subscription)
    end)

    %{state | subscriptions: %{}}
  end

  defp process_realtime_event(event_type, event, state) do
    # 該当するプロジェクションを特定
    projections_to_update = get_projections_for_event(event_type)

    # 各プロジェクションでイベントを処理
    updated_projections =
      Enum.reduce(projections_to_update, state.projections, fn projection_module, acc ->
        case process_event_with_retry(projection_module, event) do
          :ok ->
            update_projection_status(acc, projection_module, :processed)

          {:error, reason} ->
            Logger.error("Failed to process event in #{projection_module}: #{inspect(reason)}")
            update_projection_status(acc, projection_module, :error, reason)
        end
      end)

    %{state | projections: updated_projections}
  end

  defp get_projections_for_event(event_type) do
    # イベントタイプに基づいて更新すべきプロジェクションを決定
    case event_type do
      event when event in [:"category.created", :"category.updated", :"category.deleted"] ->
        [CategoryProjection]

      event
      when event in [
             :"product.created",
             :"product.updated",
             :"product.price_changed",
             :"product.deleted"
           ] ->
        [ProductProjection]

      event
      when event in [
             :"order.created",
             :"order.payment_completed",
             :"order.shipped",
             :"order.delivered",
             :"order.cancelled",
             :"inventory.reserved",
             :"inventory.reservation_failed",
             :"payment.processed",
             :"payment.failed",
             :"shipping.arranged",
             :"shipping.arrangement_failed",
             :"order.confirmed"
           ] ->
        [OrderProjection]

      _ ->
        []
    end
  end

  defp process_event_with_retry(projection_module, event) do
    RetryStrategy.execute_with_condition(
      fn ->
        try do
          projection_module.handle_event(event)
          {:ok, :processed}
        rescue
          # HTTP 関連のエラー
          e in Tesla.Error ->
            Logger.warning("HTTP error during projection: #{inspect(e)}")
            {:error, :network_error}

          e ->
            # その他のエラーはリトライ不可能として扱う
            {:error, {:projection_error, e}}
        end
      end,
      fn error ->
        RetryPolicy.retryable?(error)
      end,
      %{
        max_attempts: 3,
        base_delay: 100,
        max_delay: 2_000,
        backoff_type: :exponential
      }
    )
    |> case do
      {:ok, :processed} ->
        :ok

      {:error, :max_attempts_exceeded, errors} ->
        # 最大リトライ回数を超えた場合はDLQに送信
        last_error = errors |> List.last() |> elem(1)

        DeadLetterQueue.enqueue(
          "projection_manager",
          %{
            projection_module: projection_module,
            event: event
          },
          last_error,
          %{
            retry_count: length(errors),
            event_type: event.__struct__
          }
        )

        {:error, last_error}

      {:error, error} ->
        {:error, error}
    end
  end

  defp do_rebuild_projection(projection_module) do
    Logger.info("Rebuilding projection: #{projection_module}")

    # プロジェクションをクリア
    case projection_module.clear_all() do
      :ok ->
        # すべてのイベントを再処理
        rebuild_from_event_store(projection_module)

      {:ok, _count} ->
        # すべてのイベントを再処理
        rebuild_from_event_store(projection_module)

      {:error, reason} ->
        {:error, {:clear_failed, reason}}
    end
  end

  defp rebuild_from_event_store(projection_module) do
    # バッチでイベントを処理
    process_events_in_batches(projection_module, 0, 0)
  end

  defp process_events_in_batches(projection_module, after_id, processed_count) do
    case Shared.Infrastructure.Firestore.EventStore.get_events_after(after_id, @batch_size) do
      {:ok, []} ->
        Logger.info(
          "Rebuild completed for #{projection_module}. Processed #{processed_count} events."
        )

        {:ok, processed_count}

      {:ok, events} ->
        # バッチ内のイベントを処理
        Enum.each(events, fn event ->
          # 該当するイベントのみ処理
          if should_process_event?(projection_module, event) do
            process_event_with_retry(projection_module, event)
          end
        end)

        last_id = List.last(events).id
        new_count = processed_count + length(events)

        # 次のバッチを処理
        process_events_in_batches(projection_module, last_id, new_count)

      {:error, reason} ->
        Logger.error("Failed to fetch events: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp should_process_event?(projection_module, event) do
    event_type = get_event_type(event)
    event_type && event_type in get_handled_events(projection_module)
  end

  defp get_handled_events(CategoryProjection) do
    [:"category.created", :"category.updated", :"category.deleted"]
  end

  defp get_handled_events(ProductProjection) do
    [:"product.created", :"product.updated", :"product.price_changed", :"product.deleted"]
  end

  defp get_handled_events(OrderProjection) do
    [
      :"order.created",
      :"order.payment_completed",
      :"order.shipped",
      :"order.delivered",
      :"order.cancelled",
      :"inventory.reserved",
      :"inventory.reservation_failed",
      :"payment.processed",
      :"payment.failed",
      :"shipping.arranged",
      :"shipping.arrangement_failed",
      :"order.confirmed"
    ]
  end

  defp update_projection_status(projections, projection_module, :processed) do
    Map.update!(projections, projection_module, fn status ->
      %{status | status: :running, last_error: nil, processed_count: status.processed_count + 1}
    end)
  end

  defp update_projection_status(projections, projection_module, :error, reason) do
    Map.update!(projections, projection_module, fn status ->
      %{status | status: :error, last_error: inspect(reason)}
    end)
  end
end

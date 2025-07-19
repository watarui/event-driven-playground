defmodule Shared.Infrastructure.Saga.SagaExecutor do
  @moduledoc """
  簡素化された Saga 実行エンジン
  """
  
  use GenServer
  
  alias Shared.Config
  alias Shared.Infrastructure.Saga.{SagaDefinition, SagaState, SagaRepository}
  alias Shared.Infrastructure.Idempotency.IdempotentSaga
  alias Shared.Telemetry.Metrics
  
  require Logger
  
  # Client API
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  新しい Saga を開始
  """
  def start_saga(saga_module, trigger_event, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:start_saga, saga_module, trigger_event, metadata})
  end
  
  @doc """
  イベントを処理
  """
  def handle_event(event) do
    GenServer.cast(__MODULE__, {:handle_event, event})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    # 必要なイベントタイプを購読
    event_bus = Config.event_bus_module()
    subscribe_to_events(event_bus)
    
    # アクティブな Saga を復元
    active_sagas = restore_active_sagas()
    
    state = %{
      active_sagas: active_sagas,
      event_bus: event_bus
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:start_saga, saga_module, trigger_event, metadata}, _from, state) do
    saga_id = generate_saga_id()
    
    # Saga 状態を初期化
    saga_state = SagaState.new(saga_id, saga_module, trigger_event, metadata)
    
    # 最初のステップを実行
    case execute_next_step(saga_state) do
      {:ok, updated_saga_state} ->
        state = put_in(state.active_sagas[saga_id], updated_saga_state)
        {:reply, {:ok, saga_id}, state}
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_cast({:handle_event, event}, state) do
    # 関連する Saga を見つけて処理
    state = Enum.reduce(state.active_sagas, state, fn {saga_id, saga_state}, acc_state ->
      case process_event_for_saga(saga_state, event) do
        {:ok, updated_saga} ->
          put_in(acc_state.active_sagas[saga_id], updated_saga)
          
        {:completed, _} ->
          Metrics.saga_completed(saga_state.saga_type, :completed)
          Map.update!(acc_state, :active_sagas, &Map.delete(&1, saga_id))
          
        {:failed, _} ->
          Metrics.saga_completed(saga_state.saga_type, :failed)
          Map.update!(acc_state, :active_sagas, &Map.delete(&1, saga_id))
          
        :ignore ->
          acc_state
      end
    end)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:step_timeout, saga_id, step_name}, state) do
    case Map.get(state.active_sagas, saga_id) do
      nil ->
        {:noreply, state}
        
      saga_state ->
        Logger.warning("Step timeout: saga=#{saga_id}, step=#{step_name}")
        
        # 補償処理を開始
        case start_compensation(saga_state) do
          {:ok, compensating_saga} ->
            state = put_in(state.active_sagas[saga_id], compensating_saga)
            {:noreply, state}
            
          {:error, _} ->
            state = Map.update!(state, :active_sagas, &Map.delete(&1, saga_id))
            {:noreply, state}
        end
    end
  end
  
  # Private Functions
  
  defp subscribe_to_events(event_bus) do
    # 主要なイベントタイプのみ購読
    events = [
      :order_created,
      :inventory_reserved,
      :payment_processed,
      :shipping_arranged,
      :order_confirmed
    ]
    
    Enum.each(events, &event_bus.subscribe/1)
  end
  
  defp restore_active_sagas do
    case SagaRepository.get_active_sagas() do
      {:ok, sagas} ->
        Map.new(sagas, fn saga -> {saga.id, saga} end)
      _ ->
        %{}
    end
  end
  
  defp execute_next_step(saga_state) do
    saga_module = saga_state.saga_type
    
    case SagaDefinition.get_next_step(saga_module, saga_state) do
      nil ->
        # すべてのステップが完了
        {:completed, complete_saga(saga_state)}
        
      step_name ->
        # ステップを実行
        execute_step(saga_state, step_name)
    end
  end
  
  defp execute_step(saga_state, step_name) do
    saga_module = saga_state.saga_type
    
    # タイムアウトを設定
    timeout_ms = SagaDefinition.get_step_timeout(saga_module, step_name) || 30_000
    Process.send_after(self(), {:step_timeout, saga_state.id, step_name}, timeout_ms)
    
    # 冪等性を保証してステップを実行
    case IdempotentSaga.execute_step(saga_state.id, step_name, saga_state, saga_module) do
      {:ok, command} ->
        # コマンドを発行
        dispatch_command(command)
        
        # 状態を更新
        saga_state = SagaState.start_step(saga_state, step_name)
        SagaRepository.save(saga_state)
        
        {:ok, saga_state}
        
      {:error, reason} ->
        Logger.error("Step execution failed: #{inspect(reason)}")
        start_compensation(saga_state)
    end
  end
  
  defp dispatch_command(command) do
    Config.event_bus_module().publish_raw(:commands, command)
  end
  
  defp process_event_for_saga(saga_state, event) do
    saga_module = saga_state.saga_type
    
    case saga_module.handle_event(event, saga_state) do
      {:ok, updated_data} ->
        # データを更新して次のステップへ
        saga_state = SagaState.update_data(saga_state, updated_data)
        saga_state = SagaState.complete_step(saga_state, saga_state.current_step)
        
        case execute_next_step(saga_state) do
          {:ok, next_saga_state} ->
            {:ok, next_saga_state}
          {:completed, completed_saga_state} ->
            {:completed, completed_saga_state}
          {:error, _reason} ->
            start_compensation(saga_state)
        end
        
      :ignore ->
        :ignore
        
      {:error, _} ->
        start_compensation(saga_state)
    end
  end
  
  defp start_compensation(saga_state) do
    Logger.info("Starting compensation for saga #{saga_state.id}")
    
    saga_state = SagaState.start_compensation(saga_state)
    compensate_completed_steps(saga_state)
  end
  
  defp compensate_completed_steps(saga_state) do
    saga_module = saga_state.saga_type
    
    # 完了したステップを逆順で補償
    Enum.reverse(saga_state.completed_steps)
    |> Enum.reduce_while({:ok, saga_state}, fn step_name, {:ok, acc_state} ->
      case IdempotentSaga.compensate_step(saga_state.id, step_name, acc_state, saga_module) do
        {:ok, compensation_command} ->
          dispatch_command(compensation_command)
          {:cont, {:ok, acc_state}}
          
        {:error, reason} ->
          Logger.error("Compensation failed: #{inspect(reason)}")
          {:halt, {:error, reason}}
      end
    end)
  end
  
  defp complete_saga(saga_state) do
    saga_state = SagaState.complete(saga_state)
    SagaRepository.save(saga_state)
    Logger.info("Saga completed: #{saga_state.id}")
    saga_state
  end
  
  defp generate_saga_id do
    "saga_#{:erlang.unique_integer([:positive, :monotonic])}_#{System.system_time(:microsecond)}"
  end
end
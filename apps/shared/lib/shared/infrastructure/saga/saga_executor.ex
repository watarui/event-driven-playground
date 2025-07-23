defmodule Shared.Infrastructure.Saga.SagaExecutor do
  @moduledoc """
  Saga パターンの実行を管理する GenServer

  Saga インスタンスのライフサイクルを管理し、
  イベントのルーティングとタイムアウト処理を行います。
  """

  use GenServer
  require Logger

  alias Shared.Infrastructure.Saga.{SagaInstance, SagaRepository}
  alias Shared.Infrastructure.EventBus

  # State の構造
  defmodule State do
    @moduledoc false
    defstruct [
      # %{saga_id => pid}
      :saga_instances,
      # %{saga_name => module}
      :saga_registry,
      # %{saga_id => timer_ref}
      :timeout_refs
    ]
  end

  # Public API

  @doc """
  SagaExecutor を開始
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  新しい Saga を開始
  """
  def start_saga(saga_module, trigger_event) do
    GenServer.call(__MODULE__, {:start_saga, saga_module, trigger_event})
  end

  @doc """
  イベントを処理
  """
  def handle_event(event) do
    GenServer.cast(__MODULE__, {:handle_event, event})
  end

  @doc """
  Saga の状態を取得
  """
  def get_saga_state(saga_id) do
    GenServer.call(__MODULE__, {:get_saga_state, saga_id})
  end

  @doc """
  実行中の Saga 一覧を取得
  """
  def list_active_sagas do
    GenServer.call(__MODULE__, :list_active_sagas)
  end

  @doc """
  Saga を強制終了
  """
  def terminate_saga(saga_id, reason \\ :normal) do
    GenServer.call(__MODULE__, {:terminate_saga, saga_id, reason})
  end

  # GenServer Callbacks

  @impl true
  def init(_opts) do
    # イベントバスに登録
    :ok = EventBus.subscribe("saga_events")

    # 既存の Saga を復元
    state = %State{
      saga_instances: %{},
      saga_registry: load_saga_registry(),
      timeout_refs: %{}
    }

    # 未完了の Saga を復元
    {:ok, restore_sagas(state)}
  end

  @impl true
  def handle_call({:start_saga, saga_module, trigger_event}, _from, state) do
    case do_start_saga(saga_module, trigger_event, state) do
      {:ok, saga_id, new_state} ->
        {:reply, {:ok, saga_id}, new_state}

      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:get_saga_state, saga_id}, _from, state) do
    case Map.get(state.saga_instances, saga_id) do
      nil ->
        # DBから取得を試みる
        case SagaRepository.get_saga(saga_id) do
          {:ok, saga_data} ->
            {:reply, {:ok, saga_data}, state}

          error ->
            {:reply, error, state}
        end

      pid ->
        case SagaInstance.get_state(pid) do
          {:ok, saga_state} ->
            {:reply, {:ok, saga_state}, state}

          error ->
            {:reply, error, state}
        end
    end
  end

  @impl true
  def handle_call(:list_active_sagas, _from, state) do
    active_sagas =
      state.saga_instances
      |> Enum.map(fn {saga_id, pid} ->
        case SagaInstance.get_state(pid) do
          {:ok, saga_state} ->
            %{
              saga_id: saga_id,
              saga_name: saga_state.saga_name,
              current_step: saga_state.current_step,
              status: saga_state.status,
              started_at: saga_state.started_at
            }

          _ ->
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    {:reply, {:ok, active_sagas}, state}
  end

  @impl true
  def handle_call({:terminate_saga, saga_id, reason}, _from, state) do
    case Map.get(state.saga_instances, saga_id) do
      nil ->
        {:reply, {:error, :saga_not_found}, state}

      pid ->
        # Saga インスタンスを停止
        :ok = SagaInstance.stop(pid, reason)

        # タイムアウトタイマーをキャンセル
        new_state = cancel_timeout(saga_id, state)

        # インスタンスマップから削除
        new_state = %{new_state | saga_instances: Map.delete(new_state.saga_instances, saga_id)}

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_cast({:handle_event, event}, state) do
    # 関連する Saga にイベントをルーティング
    saga_id = extract_saga_id(event)

    case Map.get(state.saga_instances, saga_id) do
      nil ->
        # 新規 Saga の開始が必要か確認
        case find_saga_for_event(event, state.saga_registry) do
          nil ->
            {:noreply, state}

          saga_module ->
            case do_start_saga(saga_module, event, state) do
              {:ok, _saga_id, new_state} ->
                {:noreply, new_state}

              {:error, _reason} ->
                {:noreply, state}
            end
        end

      pid ->
        # 既存の Saga にイベントを送信
        :ok = SagaInstance.handle_event(pid, event)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:timeout, saga_id, step_name}, state) do
    Logger.warning("Saga timeout: saga_id=#{saga_id}, step=#{step_name}")

    case Map.get(state.saga_instances, saga_id) do
      nil ->
        {:noreply, state}

      pid ->
        # Saga インスタンスにタイムアウトを通知
        :ok = SagaInstance.handle_timeout(pid, step_name)

        # タイムアウト参照を削除
        new_state = %{state | timeout_refs: Map.delete(state.timeout_refs, saga_id)}
        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info({:saga_completed, saga_id}, state) do
    Logger.info("Saga completed: saga_id=#{saga_id}")

    # タイムアウトタイマーをキャンセル
    new_state = cancel_timeout(saga_id, state)

    # インスタンスマップから削除
    new_state = %{new_state | saga_instances: Map.delete(new_state.saga_instances, saga_id)}

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:saga_failed, saga_id, reason}, state) do
    Logger.error("Saga failed: saga_id=#{saga_id}, reason=#{inspect(reason)}")

    # タイムアウトタイマーをキャンセル
    new_state = cancel_timeout(saga_id, state)

    # インスタンスマップから削除
    new_state = %{new_state | saga_instances: Map.delete(new_state.saga_instances, saga_id)}

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:step_started, saga_id, step_name, timeout}, state) do
    # 新しいタイムアウトを設定
    new_state = set_timeout(saga_id, step_name, timeout, state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:step_completed, saga_id, _step_name}, state) do
    # 現在のタイムアウトをキャンセル
    new_state = cancel_timeout(saga_id, state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    # Saga インスタンスがクラッシュした場合
    case Enum.find(state.saga_instances, fn {_id, p} -> p == pid end) do
      nil ->
        {:noreply, state}

      {saga_id, _pid} ->
        Logger.error("Saga instance crashed: saga_id=#{saga_id}, reason=#{inspect(reason)}")

        # タイムアウトタイマーをキャンセル
        new_state = cancel_timeout(saga_id, state)

        # インスタンスマップから削除
        new_state = %{new_state | saga_instances: Map.delete(new_state.saga_instances, saga_id)}

        # 必要に応じて再起動を試みる
        case should_restart_saga?(saga_id, reason) do
          true ->
            restart_saga(saga_id, new_state)

          false ->
            {:noreply, new_state}
        end
    end
  end

  # Private Functions

  defp do_start_saga(saga_module, trigger_event, state) do
    saga_id = generate_saga_id(saga_module, trigger_event)

    # 既に実行中でないか確認
    if Map.has_key?(state.saga_instances, saga_id) do
      {:error, :saga_already_running}
    else
      # Saga インスタンスを開始
      case SagaInstance.start_link(saga_id, saga_module, trigger_event, self()) do
        {:ok, pid} ->
          # プロセスを監視
          Process.monitor(pid)

          # インスタンスマップに追加
          new_state = %{state | saga_instances: Map.put(state.saga_instances, saga_id, pid)}

          {:ok, saga_id, new_state}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp generate_saga_id(saga_module, trigger_event) do
    # Saga ID を生成（例: "OrderSaga:order-123"）
    saga_name = saga_module.saga_name()
    event_id = Map.get(trigger_event, :aggregate_id, UUID.uuid4())
    "#{saga_name}:#{event_id}"
  end

  defp extract_saga_id(event) do
    # イベントから Saga ID を抽出
    Map.get(event, :saga_id)
  end

  defp find_saga_for_event(event, saga_registry) do
    # イベントタイプに基づいて適切な Saga を見つける
    event_type = event.__struct__ |> Module.split() |> List.last()

    Enum.find_value(saga_registry, fn {_name, module} ->
      if module.can_handle_event?(event_type) do
        module
      else
        nil
      end
    end)
  end

  defp load_saga_registry do
    # 利用可能な Saga モジュールを登録
    %{
      "OrderSaga" => CommandService.Domain.Sagas.OrderSaga
      # 他の Saga も追加可能
    }
  end

  defp restore_sagas(state) do
    # 未完了の Saga を DB から復元
    case SagaRepository.get_active_sagas() do
      {:ok, sagas} ->
        Enum.reduce(sagas, state, fn saga_data, acc_state ->
          case restore_saga_instance(saga_data, acc_state) do
            {:ok, new_state} -> new_state
            {:error, _reason} -> acc_state
          end
        end)

      {:error, _reason} ->
        state
    end
  end

  defp restore_saga_instance(saga_data, state) do
    saga_module = Map.get(state.saga_registry, saga_data.saga_name)

    if saga_module do
      case SagaInstance.restore(saga_data, saga_module, self()) do
        {:ok, pid} ->
          Process.monitor(pid)

          new_state = %{
            state
            | saga_instances: Map.put(state.saga_instances, saga_data.saga_id, pid)
          }

          {:ok, new_state}

        error ->
          error
      end
    else
      {:error, :saga_module_not_found}
    end
  end

  defp set_timeout(saga_id, step_name, timeout_ms, state) do
    # 既存のタイムアウトをキャンセル
    state = cancel_timeout(saga_id, state)

    # 新しいタイムアウトを設定
    timer_ref = Process.send_after(self(), {:timeout, saga_id, step_name}, timeout_ms)

    %{state | timeout_refs: Map.put(state.timeout_refs, saga_id, timer_ref)}
  end

  defp cancel_timeout(saga_id, state) do
    case Map.get(state.timeout_refs, saga_id) do
      nil ->
        state

      timer_ref ->
        Process.cancel_timer(timer_ref)
        %{state | timeout_refs: Map.delete(state.timeout_refs, saga_id)}
    end
  end

  defp should_restart_saga?(_saga_id, :normal), do: false
  defp should_restart_saga?(_saga_id, :shutdown), do: false
  defp should_restart_saga?(_saga_id, {:shutdown, _}), do: false
  defp should_restart_saga?(_saga_id, _reason), do: true

  defp restart_saga(saga_id, state) do
    case SagaRepository.get_saga(saga_id) do
      {:ok, saga_data} ->
        case restore_saga_instance(saga_data, state) do
          {:ok, new_state} ->
            Logger.info("Saga restarted: saga_id=#{saga_id}")
            {:noreply, new_state}

          {:error, reason} ->
            Logger.error("Failed to restart saga: saga_id=#{saga_id}, reason=#{inspect(reason)}")
            {:noreply, state}
        end

      {:error, _reason} ->
        {:noreply, state}
    end
  end
end

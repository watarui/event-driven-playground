defmodule ClientService.Infrastructure.NodeConnector do
  @moduledoc """
  ノード接続を管理するプロセス

  起動時に他のノードへの接続を確立し、
  接続が切れた場合は自動的に再接続を試みます。
  """

  use GenServer

  require Logger

  @reconnect_interval 5_000
  @initial_delay 1_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def connected_nodes do
    GenServer.call(__MODULE__, :connected_nodes)
  end

  @impl true
  def init(_opts) do
    # 初期接続を少し遅らせる
    Process.send_after(self(), :connect_to_nodes, @initial_delay)

    # ノードイベントを監視
    :net_kernel.monitor_nodes(true, node_type: :all)

    state = %{
      target_nodes: [:"command@127.0.0.1", :"query@127.0.0.1"],
      connected: MapSet.new(),
      connection_attempts: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_info(:connect_to_nodes, state) do
    new_state = attempt_connections(state)

    # 全てのノードに接続できていない場合は再試行をスケジュール
    if MapSet.size(new_state.connected) < length(state.target_nodes) do
      Process.send_after(self(), :connect_to_nodes, @reconnect_interval)
    end

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:nodedown, node, _info}, state) do
    Logger.warning("Node down: #{node}")

    new_state = %{state | connected: MapSet.delete(state.connected, node)}

    # 再接続を試みる
    Process.send_after(self(), :connect_to_nodes, @reconnect_interval)

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:nodeup, node, _info}, state) do
    Logger.info("Node up: #{node}")

    new_state = %{state | connected: MapSet.put(state.connected, node)}

    {:noreply, new_state}
  end

  @impl true
  def handle_call(:connected_nodes, _from, state) do
    {:reply, MapSet.to_list(state.connected), state}
  end

  defp attempt_connections(state) do
    Enum.reduce(state.target_nodes, state, fn node, acc ->
      if MapSet.member?(acc.connected, node) do
        acc
      else
        attempts = Map.get(acc.connection_attempts, node, 0)

        case Node.connect(node) do
          true ->
            Logger.info("Successfully connected to node: #{node} after #{attempts} attempts")

            %{
              acc
              | connected: MapSet.put(acc.connected, node),
                connection_attempts: Map.delete(acc.connection_attempts, node)
            }

          false ->
            Logger.debug("Failed to connect to node: #{node} (attempt #{attempts + 1})")
            %{acc | connection_attempts: Map.put(acc.connection_attempts, node, attempts + 1)}

          :ignored ->
            Logger.debug("Connection to node #{node} was ignored")
            acc
        end
      end
    end)
  end
end

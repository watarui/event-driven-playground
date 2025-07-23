defmodule ClientService.GraphQL.Resolvers.MonitoringResolverTest do
  @moduledoc """
  MonitoringResolver のユニットテスト
  """
  use ExUnit.Case, async: false

  alias ClientService.GraphQL.Resolvers.MonitoringResolver

  setup do
    # Firestore を使用しているため、Ecto のサンドボックスは不要

    :ok
  end

  describe "get_event_store_stats/3" do
    test "returns event store statistics" do
      result = MonitoringResolver.get_event_store_stats(%{}, %{}, %{})

      assert {:ok, stats} = result
      assert is_integer(stats.total_events)
      assert is_list(stats.event_types)
      assert is_integer(stats.total_aggregates)
      assert stats.last_event_at == nil || is_binary(stats.last_event_at)
    end
  end

  describe "list_events/3" do
    test "returns filtered events" do
      args = %{limit: 10, offset: 0}
      result = MonitoringResolver.list_events(%{}, args, %{})

      assert {:ok, events} = result
      assert is_list(events)
    end

    test "applies filters correctly" do
      args = %{
        aggregate_type: "Order",
        event_type: "OrderCreated",
        limit: 5
      }

      result = MonitoringResolver.list_events(%{}, args, %{})

      assert {:ok, events} = result
      assert is_list(events)
      assert length(events) <= 5
    end
  end

  describe "get_system_statistics/3" do
    test "returns comprehensive system stats" do
      result = MonitoringResolver.get_system_statistics(%{}, %{}, %{})

      assert {:ok, stats} = result
      assert Map.has_key?(stats, :event_store)
      assert Map.has_key?(stats, :node)
      assert Map.has_key?(stats, :uptime)
      assert Map.has_key?(stats, :process_count)
      assert Map.has_key?(stats, :memory)
    end
  end

  describe "get_dashboard_stats/3" do
    @tag :skip
    test "returns dashboard statistics" do
      result = MonitoringResolver.get_dashboard_stats(%{}, %{}, %{})

      assert {:ok, stats} = result
      assert is_integer(stats.total_events)
      assert is_float(stats.events_per_minute)
      assert stats.system_health in ["healthy", "degraded", "unhealthy", "unknown"]
    end
  end

  describe "get_system_topology/3" do
    test "returns system topology information" do
      result = MonitoringResolver.get_system_topology(%{}, %{}, %{})

      assert {:ok, topology} = result
      assert is_map(topology)
      assert is_list(topology.nodes)
      assert length(topology.nodes) > 0

      # 最初のノードをチェック
      [current_node | _] = topology.nodes
      assert is_binary(current_node.name)
      assert current_node.status in ["self", "connected"]
      assert is_list(current_node.services)
    end
  end

  describe "list_sagas/3" do
    @tag :skip
    test "returns saga list with filters" do
      args = %{limit: 10, offset: 0, status: "completed"}
      result = MonitoringResolver.list_sagas(%{}, args, %{})

      assert {:ok, sagas} = result
      assert is_list(sagas)
    end
  end

  describe "get_pubsub_stats/3" do
    test "returns pubsub statistics" do
      result = MonitoringResolver.get_pubsub_stats(%{}, %{}, %{})

      assert {:ok, stats} = result
      assert is_list(stats)

      # 各トピックの統計情報をチェック
      Enum.each(stats, fn stat ->
        assert is_binary(stat.topic_name)
        assert is_integer(stat.message_count)
        assert is_integer(stat.subscriber_count)
      end)
    end
  end
end

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
      assert is_list(stats.events_by_type)
      assert is_list(stats.events_by_aggregate)
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
      assert Map.has_key?(stats, :command_db)
      assert Map.has_key?(stats, :query_db)
      assert Map.has_key?(stats, :sagas)
    end
  end

  describe "get_dashboard_stats/3" do
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

      assert {:ok, nodes} = result
      assert is_list(nodes)
      assert length(nodes) > 0

      # 最初のノードは現在のサービス
      [current_node | _] = nodes
      assert current_node.service_name == "Client Service"
      assert current_node.status == "active"
      assert is_list(current_node.connections)
    end
  end

  describe "list_sagas/3" do
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
    end
  end
end

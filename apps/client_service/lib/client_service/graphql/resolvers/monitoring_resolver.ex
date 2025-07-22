defmodule ClientService.GraphQL.Resolvers.MonitoringResolver do
  @moduledoc """
  監視系のGraphQLリゾルバー（Firestore版）
  """

  alias Shared.Infrastructure.Firestore.{EventStore, Repository}
  alias Shared.Health.HealthChecker
  require Logger

  @doc """
  イベントストアの統計情報を取得
  """
  def get_event_store_stats(_parent, _args, _resolution) do
    # TODO: 実際の統計情報を実装
    stats = %{
      total_events: 0,
      total_aggregates: 0,
      event_types: [],
      last_event_at: nil
    }
    
    {:ok, stats}
  end

  @doc """
  イベントリストを取得
  """
  def list_events(_parent, args, _resolution) do
    limit = Map.get(args, :limit, 100)
    aggregate_id = Map.get(args, :aggregate_id)
    
    if aggregate_id do
      case EventStore.get_events(aggregate_id, 0) do
        {:ok, events} -> 
          {:ok, Enum.take(events, limit)}
        error -> 
          error
      end
    else
      # TODO: 全イベントの取得を実装
      {:ok, []}
    end
  end

  @doc """
  最近のイベントを取得
  """
  def recent_events(_parent, args, _resolution) do
    _limit = Map.get(args, :limit, 10)
    
    # TODO: 最近のイベントの取得を実装
    {:ok, []}
  end

  @doc """
  システム統計情報を取得
  """
  def get_system_statistics(_parent, _args, _resolution) do
    memory_info = :erlang.memory()
    
    stats = %{
      node: node(),
      uptime: :erlang.statistics(:wall_clock) |> elem(0),
      process_count: :erlang.system_info(:process_count),
      memory: %{
        total: memory_info[:total],
        processes: memory_info[:processes],
        binary: memory_info[:binary],
        ets: memory_info[:ets]
      }
    }
    
    {:ok, stats}
  end

  @doc """
  プロジェクションの状態を取得
  """
  def get_projection_status(_parent, _args, _resolution) do
    # TODO: プロジェクションの状態を実装
    status = %{
      projections: [],
      last_processed_event_id: nil,
      is_rebuilding: false
    }
    
    {:ok, status}
  end

  @doc """
  Sagaリストを取得
  """
  def list_sagas(_parent, args, _resolution) do
    limit = Map.get(args, :limit, 100)
    
    case Repository.list("sagas", limit: limit) do
      {:ok, sagas} -> {:ok, sagas}
      error -> error
    end
  end

  @doc """
  特定のSagaを取得
  """
  def get_saga(_parent, %{id: id}, _resolution) do
    case Repository.get("sagas", id) do
      {:ok, saga} -> {:ok, saga}
      {:error, :not_found} -> {:error, "Saga not found"}
      error -> error
    end
  end

  @doc """
  Pub/Subメッセージリストを取得
  """
  def list_pubsub_messages(_parent, args, _resolution) do
    _limit = Map.get(args, :limit, 100)
    
    # TODO: Pub/Subメッセージの取得を実装
    {:ok, []}
  end

  @doc """
  Pub/Sub統計情報を取得
  """
  def get_pubsub_stats(_parent, _args, _resolution) do
    stats = %{
      topics: [],
      total_messages: 0,
      subscribers: []
    }
    
    {:ok, stats}
  end

  @doc """
  クエリ実行履歴を取得
  """
  def list_query_executions(_parent, args, _resolution) do
    limit = Map.get(args, :limit, 100)
    
    case Repository.list("query_executions", limit: limit) do
      {:ok, executions} -> {:ok, executions}
      error -> error
    end
  end

  @doc """
  コマンド実行履歴を取得
  """
  def list_command_executions(_parent, args, _resolution) do
    limit = Map.get(args, :limit, 100)
    
    case Repository.list("command_executions", limit: limit) do
      {:ok, executions} -> {:ok, executions}
      error -> error
    end
  end

  @doc """
  システムトポロジーを取得
  """
  def get_system_topology(_parent, _args, _resolution) do
    nodes = [node() | Node.list()]
    
    topology = %{
      nodes: Enum.map(nodes, fn n ->
        %{
          name: to_string(n),
          status: if(n == node(), do: "self", else: "connected"),
          services: get_node_services(n)
        }
      end)
    }
    
    {:ok, topology}
  end

  @doc """
  ダッシュボード統計を取得
  """
  def get_dashboard_stats(_parent, _args, _resolution) do
    case HealthChecker.check_health() do
      %{status: status, checks: checks} ->
        stats = %{
          health_status: status,
          health_checks: checks,
          timestamp: DateTime.utc_now()
        }
        
        {:ok, stats}
      
      _ ->
        {:error, "Failed to get dashboard stats"}
    end
  end

  # Private functions

  defp get_node_services(node_name) do
    node_str = to_string(node_name)
    
    cond do
      String.contains?(node_str, "command") -> ["CommandService"]
      String.contains?(node_str, "query") -> ["QueryService"]
      String.contains?(node_str, "client") -> ["ClientService"]
      true -> []
    end
  end
end
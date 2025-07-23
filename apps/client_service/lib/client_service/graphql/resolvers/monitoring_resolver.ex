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

    # Event Store の統計を取得
    event_store_db_stats =
      case get_event_store_stats(nil, %{}, nil) do
        {:ok, stats} ->
          %{
            total_records: stats.total_events,
            last_updated: stats.last_event_at
          }

        _ ->
          %{
            total_records: 0,
            last_updated: nil
          }
      end

    # ダミーの統計データ（実際はそれぞれのDBから取得する必要がある）
    command_db_stats = %{
      total_records: 0,
      last_updated: nil
    }

    query_db_stats = %{
      categories: 0,
      products: 0,
      orders: 0,
      last_updated: nil
    }

    saga_stats = %{
      active: 0,
      completed: 0,
      failed: 0,
      compensated: 0,
      total: 0
    }

    # GraphQL スキーマに合わせた構造を返す
    stats = %{
      event_store: event_store_db_stats,
      command_db: command_db_stats,
      query_db: query_db_stats,
      sagas: saga_stats
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
    # PubSub トピックの統計情報をリスト形式で返す
    stats = [
      %{
        topic_name: "events",
        message_count: 0,
        subscriber_count: 0,
        last_message_at: nil
      },
      %{
        topic_name: "commands",
        message_count: 0,
        subscriber_count: 0,
        last_message_at: nil
      }
    ]

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
      nodes:
        Enum.map(nodes, fn n ->
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
      %{status: status, checks: _checks} ->
        stats = %{
          system_health: to_string(status),  # atom を string に変換
          total_events: 0,
          events_per_minute: 0.0,
          active_sagas: 0,
          total_commands: 0,
          total_queries: 0,
          error_rate: 0.0,
          average_latency_ms: 0
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

defmodule ClientService.GraphQL.Resolvers.MonitoringResolver do
  @moduledoc """
  監視用クエリのリゾルバー
  """

  alias Shared.Infrastructure.EventStore.Schema.Event
  alias QueryService.Domain.Models.{Category, Product}
  alias QueryService.Domain.ReadModels.Order
  alias ClientService.PubSubBroadcaster
  import Ecto.Query

  @doc """
  イベントストアの統計情報を取得
  """
  def get_event_store_stats(_parent, _args, _resolution) do
    # 総イベント数
    total_events = Shared.Infrastructure.EventStore.Repo.aggregate(Event, :count)

    # イベントタイプ別の集計
    events_by_type =
      Event
      |> group_by(:event_type)
      |> select([e], %{event_type: e.event_type, count: count(e.id)})
      |> Shared.Infrastructure.EventStore.Repo.all()

    # アグリゲートタイプ別の集計
    events_by_aggregate =
      Event
      |> group_by(:aggregate_type)
      |> select([e], %{aggregate_type: e.aggregate_type, count: count(e.id)})
      |> Shared.Infrastructure.EventStore.Repo.all()

    # 最新のシーケンス番号
    latest_sequence =
      Event
      |> select([e], max(e.global_sequence))
      |> Shared.Infrastructure.EventStore.Repo.one()

    {:ok,
     %{
       total_events: total_events || 0,
       events_by_type: events_by_type,
       events_by_aggregate: events_by_aggregate,
       latest_sequence: latest_sequence
     }}
  end

  @doc """
  イベント一覧を取得
  """
  def list_events(_parent, args, _resolution) do
    query = from(e in Event)

    query =
      if args[:aggregate_id] do
        from(e in query, where: e.aggregate_id == ^args.aggregate_id)
      else
        query
      end

    query =
      if args[:aggregate_type] do
        from(e in query, where: e.aggregate_type == ^args.aggregate_type)
      else
        query
      end

    query =
      if args[:event_type] do
        from(e in query, where: e.event_type == ^args.event_type)
      else
        query
      end

    query =
      if args[:after_id] do
        from(e in query, where: e.id > ^args.after_id)
      else
        query
      end

    events =
      query
      |> order_by(desc: :id)
      |> limit(^(args[:limit] || 100))
      |> Shared.Infrastructure.EventStore.Repo.all()
      |> Enum.map(fn event ->
        Map.update!(event, :inserted_at, fn dt ->
          case dt do
            %NaiveDateTime{} = dt -> NaiveDateTime.to_string(dt)
            %DateTime{} = dt -> DateTime.to_string(dt)
            dt -> to_string(dt)
          end
        end)
      end)

    {:ok, events}
  end

  @doc """
  最新のイベントを取得
  """
  def recent_events(_parent, args, _resolution) do
    limit = args[:limit] || 50

    events =
      Event
      |> order_by(desc: :id)
      |> limit(^limit)
      |> Shared.Infrastructure.EventStore.Repo.all()
      |> Enum.map(fn event ->
        Map.update!(event, :inserted_at, fn dt ->
          case dt do
            %NaiveDateTime{} = dt -> NaiveDateTime.to_string(dt)
            %DateTime{} = dt -> DateTime.to_string(dt)
            dt -> to_string(dt)
          end
        end)
      end)

    {:ok, events}
  end

  @doc """
  システム統計を取得
  """
  def get_system_statistics(_parent, _args, _resolution) do
    # Event Store の統計
    event_store_count = Shared.Infrastructure.EventStore.Repo.aggregate(Event, :count) || 0

    # Command DB の統計（カテゴリと商品のみ）
    categories_cmd_count = get_command_count("categories")
    products_cmd_count = get_command_count("products")
    command_db_count = categories_cmd_count + products_cmd_count

    # Query DB の統計
    # 注: 実際のデータはQuery DBに存在するが、RPC接続の問題により0と表示される場合があります
    # 実際の値: categories=10, products=17, orders=0
    categories_count = get_query_count(Category)
    products_count = get_query_count(Product)
    orders_count = get_query_count(Order)

    # SAGA の統計
    saga_stats = get_saga_stats()

    current_time = DateTime.utc_now() |> DateTime.to_string()

    {:ok,
     %{
       event_store: %{
         total_records: event_store_count,
         last_updated: current_time
       },
       command_db: %{
         total_records: command_db_count,
         last_updated: current_time
       },
       query_db: %{
         categories: categories_count,
         products: products_count,
         orders: orders_count,
         last_updated: current_time
       },
       sagas: saga_stats
     }}
  end

  @doc """
  プロジェクションの状態を取得
  """
  def get_projection_status(_parent, _args, _resolution) do
    # Query Service のプロジェクションマネージャーから状態を取得
    case :rpc.call(
           :"query@127.0.0.1",
           QueryService.Infrastructure.ProjectionManager,
           :get_status,
           []
         ) do
      {:badrpc, _reason} ->
        {:error, "Query Service に接続できません"}

      status when is_map(status) ->
        projections =
          Enum.map(status, fn {module, info} ->
            %{
              name: inspect(module),
              status: to_string(info.status),
              last_error: info.last_error,
              processed_count: info.processed_count
            }
          end)

        {:ok, projections}

      _ ->
        {:error, "プロジェクションの状態を取得できません"}
    end
  end

  # Private functions

  defp get_query_count(module) do
    try do
      # 直接 Query DB に接続して集計
      table_name =
        case module do
          Category -> "categories"
          Product -> "products"
          Order -> "orders"
          _ -> nil
        end

      if table_name do
        # Query DB に直接接続
        conn_config = [
          database: "event_driven_playground_query_dev",
          hostname: "localhost",
          port: 5434,
          username: "postgres",
          password: "postgres"
        ]

        case Postgrex.start_link(conn_config) do
          {:ok, conn} ->
            try do
              case Postgrex.query(conn, "SELECT COUNT(*) FROM #{table_name}", []) do
                {:ok, %{rows: [[count]]}} ->
                  GenServer.stop(conn)
                  count || 0

                _ ->
                  GenServer.stop(conn)
                  0
              end
            catch
              _ ->
                GenServer.stop(conn)
                0
            end

          _ ->
            0
        end
      else
        0
      end
    rescue
      _ -> 0
    end
  end

  defp get_command_count(table_name) do
    try do
      # Command Service の Repo を使用
      query = "SELECT COUNT(*) FROM #{table_name}"

      case :rpc.call(:"command@127.0.0.1", CommandService.Repo, :query, [query]) do
        {:badrpc, _} -> 0
        {:ok, %{rows: [[count]]}} -> count || 0
        _ -> 0
      end
    rescue
      _ -> 0
    end
  end

  defp get_saga_stats do
    try do
      # SAGA テーブルから統計を取得
      query = """
      SELECT 
        COUNT(*) FILTER (WHERE status = 'started') as active,
        COUNT(*) FILTER (WHERE status = 'completed') as completed,
        COUNT(*) FILTER (WHERE status = 'failed') as failed,
        COUNT(*) FILTER (WHERE status = 'compensated') as compensated,
        COUNT(*) as total
      FROM event_store.sagas
      """

      case Shared.Infrastructure.EventStore.Repo.query(query) do
        {:ok, %{rows: [[active, completed, failed, compensated, total]]}} ->
          %{
            active: active || 0,
            completed: completed || 0,
            failed: failed || 0,
            compensated: compensated || 0,
            total: total || 0
          }

        _ ->
          %{active: 0, completed: 0, failed: 0, compensated: 0, total: 0}
      end
    rescue
      _ ->
        %{active: 0, completed: 0, failed: 0, compensated: 0, total: 0}
    end
  end

  @doc """
  Saga の一覧を取得
  """
  def list_sagas(_parent, args, _resolution) do
    base_query = "SELECT * FROM event_store.sagas"

    conditions = []
    params = []
    param_index = 1

    # status フィルタ
    {conditions, params, param_index} =
      if args[:status] do
        {["status = $#{param_index}" | conditions], params ++ [args[:status]], param_index + 1}
      else
        {conditions, params, param_index}
      end

    # saga_type フィルタ
    {conditions, params, param_index} =
      if args[:saga_type] do
        {["saga_type = $#{param_index}" | conditions], params ++ [args[:saga_type]],
         param_index + 1}
      else
        {conditions, params, param_index}
      end

    where_clause =
      if conditions != [], do: " WHERE " <> Enum.join(Enum.reverse(conditions), " AND "), else: ""

    # LIMIT と OFFSET を追加
    limit_offset_query =
      " ORDER BY updated_at DESC LIMIT $#{param_index} OFFSET $#{param_index + 1}"

    query = base_query <> where_clause <> limit_offset_query

    params = params ++ [args[:limit] || 50, args[:offset] || 0]

    case Shared.Infrastructure.EventStore.Repo.query(query, params) do
      {:ok, %{rows: rows, columns: columns}} ->
        sagas =
          Enum.map(rows, fn row ->
            Enum.zip(columns, row)
            |> Enum.into(%{})
            |> format_saga_from_row()
          end)

        {:ok, sagas}

      {:error, error} ->
        {:error, "Failed to fetch sagas: #{inspect(error)}"}
    end
  end

  @doc """
  特定の Saga を取得
  """
  def get_saga(_parent, %{id: id}, _resolution) do
    query = "SELECT * FROM event_store.sagas WHERE id = $1 LIMIT 1"

    # UUID を適切な形式に変換
    id_binary =
      case id do
        # すでにバイナリ形式
        <<_::288>> = binary ->
          binary

        string_id ->
          case Ecto.UUID.dump(string_id) do
            {:ok, binary} -> binary
            _ -> id
          end
      end

    case Shared.Infrastructure.EventStore.Repo.query(query, [id_binary]) do
      {:ok, %{rows: [row], columns: columns}} ->
        saga =
          Enum.zip(columns, row)
          |> Enum.into(%{})
          |> format_saga_from_row()

        {:ok, saga}

      {:ok, %{rows: []}} ->
        {:error, "Saga not found"}

      {:error, error} ->
        {:error, "Failed to fetch saga: #{inspect(error)}"}
    end
  end

  @doc """
  PubSub メッセージ履歴を取得
  """
  def list_pubsub_messages(_parent, args, _resolution) do
    # メモリ内キャッシュから取得（リアルタイムモニタリングのため）
    messages = PubSubBroadcaster.get_recent_messages()

    filtered_messages =
      messages
      |> Enum.filter(fn msg ->
        (is_nil(args[:topic]) || msg.topic == args[:topic]) &&
          (is_nil(args[:after_timestamp]) ||
             DateTime.compare(msg.timestamp, args[:after_timestamp]) == :gt)
      end)
      |> Enum.take(args[:limit] || 100)

    {:ok, filtered_messages}
  end

  @doc """
  PubSub トピック統計を取得
  """
  def get_pubsub_stats(_parent, _args, _resolution) do
    stats = PubSubBroadcaster.get_topic_stats()
    {:ok, stats}
  end

  @doc """
  クエリ実行履歴を取得
  """
  def list_query_executions(_parent, _args, _resolution) do
    # TODO: クエリ実行の追跡を実装
    {:ok, []}
  end

  @doc """
  コマンド実行履歴を取得
  """
  def list_command_executions(_parent, _args, _resolution) do
    # TODO: コマンド実行の追跡を実装
    {:ok, []}
  end

  @doc """
  システムトポロジーを取得
  """
  def get_system_topology(_parent, _args, _resolution) do
    nodes = [
      %{
        service_name: "Client Service",
        node_name: Node.self(),
        status: "active",
        uptime_seconds: get_uptime(),
        memory_usage_mb: get_memory_usage(),
        cpu_usage_percent: 0.0,
        message_queue_size: Process.info(self(), :message_queue_len) |> elem(1),
        connections: [
          %{
            target_service: "Command Service",
            connection_type: "RPC",
            status: check_rpc_connection(:"command@127.0.0.1"),
            latency_ms: 0
          },
          %{
            target_service: "Query Service",
            connection_type: "RPC",
            status: check_rpc_connection(:"query@127.0.0.1"),
            latency_ms: 0
          }
        ]
      }
    ]

    # 他のサービスの状態も取得
    for node <- [:"command@127.0.0.1", :"query@127.0.0.1"] do
      case :rpc.call(node, :erlang, :node, []) do
        {:badrpc, _} ->
          nil

        _ ->
          %{
            service_name:
              (node |> to_string() |> String.split("@") |> List.first() |> String.capitalize()) <>
                " Service",
            node_name: node,
            status: "active",
            uptime_seconds: 0,
            memory_usage_mb: 0,
            cpu_usage_percent: 0.0,
            message_queue_size: 0,
            connections: []
          }
      end
    end
    |> Enum.reject(&is_nil/1)
    |> then(&(nodes ++ &1))
    |> then(&{:ok, &1})
  end

  @doc """
  統合ダッシュボード統計を取得
  """
  def get_dashboard_stats(_parent, _args, _resolution) do
    total_events = Shared.Infrastructure.EventStore.Repo.aggregate(Event, :count) || 0
    saga_stats = get_saga_stats()

    # イベントレートの計算（1分間のイベント数）
    one_minute_ago = DateTime.utc_now() |> DateTime.add(-60, :second)

    recent_events_count =
      Event
      |> where([e], e.inserted_at > ^one_minute_ago)
      |> Shared.Infrastructure.EventStore.Repo.aggregate(:count)
      |> Kernel.||(0)

    {:ok,
     %{
       total_events: total_events,
       events_per_minute: recent_events_count * 1.0,
       active_sagas: saga_stats.active,
       # TODO: コマンド数の追跡
       total_commands: 0,
       # TODO: クエリ数の追跡
       total_queries: 0,
       system_health: determine_system_health(),
       # TODO: エラーレートの計算
       error_rate: 0.0,
       # TODO: レイテンシの計測
       average_latency_ms: 0
     }}
  end

  # Private helper functions

  defp format_saga_from_row(row) do
    state =
      case row["state"] do
        nil ->
          %{}

        json_string ->
          case Jason.decode(json_string) do
            {:ok, decoded} -> decoded
            _ -> %{}
          end
      end

    %{
      id:
        case row["id"] do
          <<_::128>> = binary -> Ecto.UUID.load(binary) |> elem(1)
          id -> id
        end,
      saga_type: row["saga_type"],
      status: row["status"],
      state: state,
      # TODO: コマンド履歴の追加
      commands_dispatched: [],
      events_handled: Map.get(state, "handled_events", []),
      created_at: row["created_at"],
      updated_at: row["updated_at"],
      correlation_id: Map.get(state, "correlation_id")
    }
  end

  defp get_uptime do
    {uptime, _} = :erlang.statistics(:wall_clock)
    div(uptime, 1000)
  end

  defp get_memory_usage do
    memory = :erlang.memory()
    div(memory[:total], 1024 * 1024)
  end

  defp check_rpc_connection(node) do
    case :net_adm.ping(node) do
      :pong -> "connected"
      :pang -> "disconnected"
    end
  end

  defp determine_system_health do
    # TODO: より詳細なヘルスチェック
    "healthy"
  end
end

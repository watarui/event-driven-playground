defmodule ClientService.GraphQL.Types.Monitoring do
  @moduledoc """
  監視用の GraphQL タイプ定義
  """

  use Absinthe.Schema.Notation

  @desc "イベントストアの統計情報"
  object :event_store_stats do
    field(:total_events, non_null(:integer))
    field(:events_by_type, list_of(:event_type_count))
    field(:events_by_aggregate, list_of(:aggregate_type_count))
    field(:latest_sequence, :integer)
  end

  @desc "イベントタイプ別のカウント"
  object :event_type_count do
    field(:event_type, non_null(:string))
    field(:count, non_null(:integer))
  end

  @desc "アグリゲートタイプ別のカウント"
  object :aggregate_type_count do
    field(:aggregate_type, non_null(:string))
    field(:count, non_null(:integer))
  end

  @desc "イベント"
  object :event do
    field(:id, non_null(:integer))
    field(:aggregate_id, non_null(:id))
    field(:aggregate_type, non_null(:string))
    field(:event_type, non_null(:string))
    field(:event_data, :json)
    field(:event_version, non_null(:integer))
    field(:global_sequence, :integer)
    field(:metadata, :json)
    field(:inserted_at, non_null(:string))
  end

  @desc "システム統計"
  object :system_statistics do
    field(:event_store, non_null(:database_stats))
    field(:command_db, non_null(:database_stats))
    field(:query_db, non_null(:read_model_stats))
    field(:sagas, non_null(:saga_stats))
  end

  @desc "データベース統計"
  object :database_stats do
    field(:total_records, non_null(:integer))
    field(:last_updated, :string)
  end

  @desc "読み取りモデル統計"
  object :read_model_stats do
    field(:categories, non_null(:integer))
    field(:products, non_null(:integer))
    field(:orders, non_null(:integer))
    field(:last_updated, :string)
  end

  @desc "SAGA統計"
  object :saga_stats do
    field(:active, non_null(:integer))
    field(:completed, non_null(:integer))
    field(:failed, non_null(:integer))
    field(:compensated, non_null(:integer))
    field(:total, non_null(:integer))
  end

  @desc "プロジェクションの状態"
  object :projection_status do
    field(:name, non_null(:string))
    field(:status, non_null(:string))
    field(:last_error, :string)
    field(:processed_count, non_null(:integer))
  end

  @desc "Saga の詳細情報"
  object :saga_detail do
    field(:id, non_null(:id))
    field(:saga_type, non_null(:string))
    field(:status, non_null(:string))
    field(:state, :json)
    field(:commands_dispatched, list_of(:saga_command))
    field(:events_handled, list_of(:string))
    field(:created_at, non_null(:datetime))
    field(:updated_at, non_null(:datetime))
    field(:correlation_id, :string)
  end

  @desc "Saga が発行したコマンド"
  object :saga_command do
    field(:command_type, non_null(:string))
    field(:command_data, :json)
    field(:timestamp, non_null(:datetime))
  end

  @desc "PubSub メッセージ"
  object :pubsub_message do
    field(:id, non_null(:id))
    field(:topic, non_null(:string))
    field(:message_type, non_null(:string))
    field(:payload, :json)
    field(:timestamp, non_null(:datetime))
    field(:source_service, :string)
  end

  @desc "PubSub トピック統計"
  object :pubsub_topic_stats do
    field(:topic, non_null(:string))
    field(:message_count, non_null(:integer))
    field(:messages_per_minute, non_null(:float))
    field(:last_message_at, :datetime)
  end

  @desc "クエリ実行履歴"
  object :query_execution do
    field(:id, non_null(:id))
    field(:query_type, non_null(:string))
    field(:query_params, :json)
    field(:execution_time_ms, non_null(:integer))
    field(:result_count, :integer)
    field(:status, non_null(:string))
    field(:error_message, :string)
    field(:timestamp, non_null(:datetime))
  end

  @desc "コマンド実行履歴"
  object :command_execution do
    field(:id, non_null(:id))
    field(:command_type, non_null(:string))
    field(:command_data, :json)
    field(:aggregate_id, :id)
    field(:aggregate_type, :string)
    field(:execution_time_ms, non_null(:integer))
    field(:status, non_null(:string))
    field(:error_message, :string)
    field(:events_generated, list_of(:string))
    field(:timestamp, non_null(:datetime))
  end

  @desc "システムトポロジーノード"
  object :system_topology_node do
    field(:service_name, non_null(:string))
    field(:node_name, non_null(:string))
    field(:status, non_null(:string))
    field(:uptime_seconds, :integer)
    field(:memory_usage_mb, :integer)
    field(:cpu_usage_percent, :float)
    field(:message_queue_size, :integer)
    field(:connections, list_of(:service_connection))
  end

  @desc "サービス間接続"
  object :service_connection do
    field(:target_service, non_null(:string))
    field(:connection_type, non_null(:string))
    field(:status, non_null(:string))
    field(:latency_ms, :integer)
  end

  @desc "リアルタイムダッシュボード統計"
  object :dashboard_stats do
    field(:total_events, non_null(:integer))
    field(:events_per_minute, non_null(:float))
    field(:active_sagas, non_null(:integer))
    field(:total_commands, non_null(:integer))
    field(:total_queries, non_null(:integer))
    field(:system_health, non_null(:string))
    field(:error_rate, non_null(:float))
    field(:average_latency_ms, non_null(:integer))
  end
end

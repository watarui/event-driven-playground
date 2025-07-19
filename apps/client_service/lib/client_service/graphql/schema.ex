defmodule ClientService.GraphQL.Schema do
  @moduledoc """
  GraphQL スキーマ定義
  """

  use Absinthe.Schema

  import_types(Absinthe.Type.Custom)
  import_types(ClientService.GraphQL.Types.Common)
  import_types(ClientService.GraphQL.Types.Category)
  import_types(ClientService.GraphQL.Types.Product)
  import_types(ClientService.GraphQL.Types.Order)
  import_types(ClientService.GraphQL.Types.Monitoring)
  import_types(ClientService.GraphQL.Types.Health)

  alias ClientService.GraphQL.Dataloader

  # PubSub版のリゾルバーを使用
  alias ClientService.GraphQL.Resolvers.CategoryResolverPubsub, as: CategoryResolver
  alias ClientService.GraphQL.Resolvers.ProductResolverPubsub, as: ProductResolver
  alias ClientService.GraphQL.Resolvers.OrderResolverPubsub, as: OrderResolver
  alias ClientService.GraphQL.Resolvers.MonitoringResolver
  alias ClientService.GraphQL.Resolvers.HealthResolver

  query do
    @desc "カテゴリを取得"
    field :category, :category do
      arg(:id, non_null(:id))
      resolve(&CategoryResolver.get_category/3)
    end

    @desc "カテゴリ一覧を取得"
    field :categories, list_of(:category) do
      arg(:limit, :integer, default_value: 20)
      arg(:offset, :integer, default_value: 0)
      arg(:sort_by, :string, default_value: "name")
      arg(:sort_order, :sort_order, default_value: :asc)
      resolve(&CategoryResolver.list_categories/3)
    end

    @desc "カテゴリを検索"
    field :search_categories, list_of(:category) do
      arg(:search_term, non_null(:string))
      arg(:limit, :integer, default_value: 20)
      arg(:offset, :integer, default_value: 0)
      resolve(&CategoryResolver.search_categories/3)
    end

    @desc "商品を取得"
    field :product, :product do
      arg(:id, non_null(:id))
      resolve(&ProductResolver.get_product/3)
    end

    @desc "商品一覧を取得"
    field :products, list_of(:product) do
      arg(:category_id, :id)
      arg(:limit, :integer, default_value: 20)
      arg(:offset, :integer, default_value: 0)
      arg(:sort_by, :string, default_value: "name")
      arg(:sort_order, :sort_order, default_value: :asc)
      arg(:min_price, :decimal)
      arg(:max_price, :decimal)
      resolve(&ProductResolver.list_products/3)
    end

    @desc "商品を検索"
    field :search_products, list_of(:product) do
      arg(:search_term, non_null(:string))
      arg(:category_id, :id)
      arg(:limit, :integer, default_value: 20)
      arg(:offset, :integer, default_value: 0)
      resolve(&ProductResolver.search_products/3)
    end

    @desc "注文を取得"
    field :order, :order do
      arg(:id, non_null(:id))
      resolve(&OrderResolver.get_order/3)
    end

    @desc "注文一覧を取得"
    field :orders, list_of(:order) do
      arg(:user_id, :string)
      arg(:status, :order_status)
      arg(:limit, :integer, default_value: 20)
      arg(:offset, :integer, default_value: 0)
      resolve(&OrderResolver.list_orders/3)
    end

    @desc "ユーザーの注文一覧を取得"
    field :user_orders, list_of(:order) do
      arg(:user_id, non_null(:string))
      arg(:limit, :integer, default_value: 20)
      arg(:offset, :integer, default_value: 0)
      resolve(&OrderResolver.list_user_orders/3)
    end

    # 監視用クエリ
    @desc "イベントストアの統計情報を取得"
    field :event_store_stats, non_null(:event_store_stats) do
      resolve(&MonitoringResolver.get_event_store_stats/3)
    end

    @desc "イベント一覧を取得"
    field :events, list_of(:event) do
      arg(:aggregate_id, :id)
      arg(:aggregate_type, :string)
      arg(:event_type, :string)
      arg(:limit, :integer, default_value: 100)
      arg(:after_id, :integer)
      resolve(&MonitoringResolver.list_events/3)
    end

    @desc "最新のイベントを取得"
    field :recent_events, list_of(:event) do
      arg(:limit, :integer, default_value: 50)
      resolve(&MonitoringResolver.recent_events/3)
    end

    @desc "システム統計を取得"
    field :system_statistics, non_null(:system_statistics) do
      resolve(&MonitoringResolver.get_system_statistics/3)
    end

    @desc "プロジェクションの状態を取得"
    field :projection_status, list_of(:projection_status) do
      resolve(&MonitoringResolver.get_projection_status/3)
    end

    @desc "Saga の詳細情報を取得"
    field :sagas, list_of(:saga_detail) do
      arg(:status, :string)
      arg(:saga_type, :string)
      arg(:limit, :integer, default_value: 50)
      arg(:offset, :integer, default_value: 0)
      resolve(&MonitoringResolver.list_sagas/3)
    end

    @desc "特定の Saga を取得"
    field :saga, :saga_detail do
      arg(:id, non_null(:id))
      resolve(&MonitoringResolver.get_saga/3)
    end

    @desc "PubSub メッセージ履歴を取得"
    field :pubsub_messages, list_of(:pubsub_message) do
      arg(:topic, :string)
      arg(:limit, :integer, default_value: 100)
      arg(:after_timestamp, :datetime)
      resolve(&MonitoringResolver.list_pubsub_messages/3)
    end

    @desc "PubSub トピック統計を取得"
    field :pubsub_stats, list_of(:pubsub_topic_stats) do
      resolve(&MonitoringResolver.get_pubsub_stats/3)
    end

    @desc "クエリ実行履歴を取得"
    field :query_executions, list_of(:query_execution) do
      arg(:query_type, :string)
      arg(:status, :string)
      arg(:limit, :integer, default_value: 100)
      arg(:after_timestamp, :datetime)
      resolve(&MonitoringResolver.list_query_executions/3)
    end

    @desc "コマンド実行履歴を取得"
    field :command_executions, list_of(:command_execution) do
      arg(:command_type, :string)
      arg(:status, :string)
      arg(:limit, :integer, default_value: 100)
      arg(:after_timestamp, :datetime)
      resolve(&MonitoringResolver.list_command_executions/3)
    end

    @desc "システムトポロジーを取得"
    field :system_topology, list_of(:system_topology_node) do
      resolve(&MonitoringResolver.get_system_topology/3)
    end

    @desc "統合ダッシュボード統計を取得"
    field :dashboard_stats, non_null(:dashboard_stats) do
      resolve(&MonitoringResolver.get_dashboard_stats/3)
    end

    @desc "ヘルスチェック結果を取得"
    field :health, :health_report do
      resolve(&HealthResolver.get_health/3)
    end

    @desc "メモリ情報を取得"
    field :memory_info, :memory_info do
      resolve(&HealthResolver.get_memory_info/3)
    end

    @desc "特定サービスのヘルスチェック"
    field :service_health, :health_report do
      arg(:service_name, non_null(:string))
      resolve(&HealthResolver.check_service/3)
    end
  end

  mutation do
    @desc "カテゴリを作成"
    field :create_category, :category do
      arg(:input, non_null(:create_category_input))
      middleware(ClientService.GraphQL.Middleware.Authorization, :admin)
      resolve(&CategoryResolver.create_category/3)
    end

    @desc "カテゴリを更新"
    field :update_category, :category do
      arg(:id, non_null(:id))
      arg(:input, non_null(:update_category_input))
      middleware(ClientService.GraphQL.Middleware.Authorization, :admin)
      resolve(&CategoryResolver.update_category/3)
    end

    @desc "カテゴリを削除"
    field :delete_category, :delete_result do
      arg(:id, non_null(:id))
      middleware(ClientService.GraphQL.Middleware.Authorization, :admin)
      resolve(&CategoryResolver.delete_category/3)
    end

    @desc "商品を作成"
    field :create_product, :product do
      arg(:input, non_null(:create_product_input))
      middleware(ClientService.GraphQL.Middleware.Authorization, :admin)
      resolve(&ProductResolver.create_product/3)
    end

    @desc "商品を更新"
    field :update_product, :product do
      arg(:id, non_null(:id))
      arg(:input, non_null(:update_product_input))
      middleware(ClientService.GraphQL.Middleware.Authorization, :admin)
      resolve(&ProductResolver.update_product/3)
    end

    @desc "商品価格を変更"
    field :change_product_price, :product do
      arg(:id, non_null(:id))
      arg(:new_price, non_null(:decimal))
      middleware(ClientService.GraphQL.Middleware.Authorization, :admin)
      resolve(&ProductResolver.change_product_price/3)
    end

    @desc "商品を削除"
    field :delete_product, :delete_result do
      arg(:id, non_null(:id))
      middleware(ClientService.GraphQL.Middleware.Authorization, :admin)
      resolve(&ProductResolver.delete_product/3)
    end

    @desc "注文を作成（SAGAを開始）"
    field :create_order, :order_result do
      arg(:input, non_null(:create_order_input))
      middleware(ClientService.GraphQL.Middleware.Authorization, :write)
      resolve(&OrderResolver.create_order/3)
    end
  end

  # Subscription の定義
  subscription do
    @desc "リアルタイムイベントストリーム"
    field :event_stream, :event do
      arg(:aggregate_type, :string)
      arg(:event_type, :string)

      config(fn args, _info ->
        topics =
          if args[:aggregate_type] do
            ["events:#{args.aggregate_type}"]
          else
            ["events:*"]
          end

        {:ok, topic: topics}
      end)
    end

    @desc "PubSub メッセージのリアルタイムストリーム"
    field :pubsub_stream, :pubsub_message do
      arg(:topic, :string)

      config(fn args, _info ->
        topics =
          if args[:topic] do
            ["pubsub:#{args.topic}"]
          else
            ["pubsub:*"]
          end

        {:ok, topic: topics}
      end)
    end

    @desc "Saga 状態のリアルタイム更新"
    field :saga_updates, :saga_detail do
      arg(:saga_type, :string)

      config(fn args, _info ->
        topics =
          if args[:saga_type] do
            ["sagas:#{args.saga_type}"]
          else
            ["sagas:*"]
          end

        {:ok, topic: topics}
      end)
    end

    @desc "システム統計のリアルタイム更新"
    field :dashboard_stats_stream, :dashboard_stats do
      config(fn _args, _info ->
        {:ok, topic: "dashboard:stats"}
      end)
    end
  end

  # Dataloader の設定
  def context(ctx) do
    loader = Dataloader.new()
    Map.put(ctx, :loader, loader)
  end

  def plugins do
    # Dataloader の依存関係の問題を回避するため一時的に無効化
    # [Absinthe.Middleware.Dataloader] ++ Absinthe.Plugin.defaults()
    Absinthe.Plugin.defaults()
  end

  @doc """
  ミドルウェアの設定
  """
  def middleware(middleware, _field, _object) do
    middleware ++ [ClientService.GraphQL.Middleware.ErrorHandler]
  end
end

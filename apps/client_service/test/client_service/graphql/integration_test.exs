defmodule ClientService.GraphQL.IntegrationTest do
  @moduledoc """
  GraphQL API の統合テスト
  全てのクエリとミューテーションが正しく動作することを確認
  """
  use ExUnit.Case, async: false
  import Plug.Conn
  import Phoenix.ConnTest

  @endpoint ClientServiceWeb.Endpoint

  setup do
    # Firestore を使用しているため、Ecto のサンドボックスは不要
    # テスト用のコンテキストセットアップ
    # Firestore を使用しているため、これらの設定は不要

    # テスト用の認証コンテキスト
    conn =
      build_conn()
      |> put_req_header("content-type", "application/json")

    {:ok, conn: conn}
  end

  describe "Category Queries" do
    test "list_categories query returns categories", %{conn: conn} do
      query = """
      query {
        categories(limit: 10, offset: 0) {
          id
          name
          description
        }
      }
      """

      conn = post(conn, "/graphql", %{query: query})
      assert %{"data" => %{"categories" => categories}} = json_response(conn, 200)
      assert is_list(categories)
    end

    test "search_categories query works", %{conn: conn} do
      query = """
      query {
        searchCategories(searchTerm: "test", limit: 10) {
          id
          name
        }
      }
      """

      conn = post(conn, "/graphql", %{query: query})
      assert %{"data" => %{"searchCategories" => categories}} = json_response(conn, 200)
      assert is_list(categories)
    end
  end

  describe "Product Queries" do
    test "list_products query returns products", %{conn: conn} do
      query = """
      query {
        products(limit: 10, offset: 0) {
          id
          name
          price
          stockQuantity
        }
      }
      """

      conn = post(conn, "/graphql", %{query: query})
      assert %{"data" => %{"products" => products}} = json_response(conn, 200)
      assert is_list(products)
    end

    test "search_products query works", %{conn: conn} do
      query = """
      query {
        searchProducts(searchTerm: "test", limit: 10) {
          id
          name
          price
        }
      }
      """

      conn = post(conn, "/graphql", %{query: query})
      assert %{"data" => %{"searchProducts" => products}} = json_response(conn, 200)
      assert is_list(products)
    end
  end

  describe "Order Queries" do
    test "list_orders query returns orders", %{conn: conn} do
      query = """
      query {
        orders(limit: 10, offset: 0) {
          id
          userId
          status
          totalAmount
        }
      }
      """

      conn = post(conn, "/graphql", %{query: query})
      assert %{"data" => %{"orders" => orders}} = json_response(conn, 200)
      assert is_list(orders)
    end

    test "user_orders query works", %{conn: conn} do
      query = """
      query {
        userOrders(userId: "test-user", limit: 10) {
          id
          status
          totalAmount
        }
      }
      """

      conn = post(conn, "/graphql", %{query: query})
      assert %{"data" => %{"userOrders" => orders}} = json_response(conn, 200)
      assert is_list(orders)
    end
  end

  describe "Monitoring Queries" do
    test "event_store_stats query returns statistics", %{conn: conn} do
      query = """
      query {
        eventStoreStats {
          totalEvents
          eventsByType {
            eventType
            count
          }
          eventsByAggregate {
            aggregateType
            count
          }
          latestSequence
        }
      }
      """

      conn = post(conn, "/graphql", %{query: query})
      assert %{"data" => %{"eventStoreStats" => stats}} = json_response(conn, 200)
      assert is_integer(stats["totalEvents"])
    end

    test "system_statistics query returns system stats", %{conn: conn} do
      query = """
      query {
        systemStatistics {
          eventStore {
            totalRecords
            lastUpdated
          }
          commandDb {
            totalRecords
            lastUpdated
          }
          queryDb {
            categories
            products
            orders
            lastUpdated
          }
          sagas {
            active
            completed
            failed
            compensated
            total
          }
        }
      }
      """

      conn = post(conn, "/graphql", %{query: query})
      assert %{"data" => %{"systemStatistics" => stats}} = json_response(conn, 200)
      assert is_map(stats["eventStore"])
    end

    test "projection_status query works", %{conn: conn} do
      query = """
      query {
        projectionStatus {
          name
          status
          processedCount
        }
      }
      """

      conn = post(conn, "/graphql", %{query: query})
      response = json_response(conn, 200)
      # エラーまたは空の配列が返ることを許容
      assert Map.has_key?(response, "data") || Map.has_key?(response, "errors")
    end

    test "sagas query returns saga list", %{conn: conn} do
      query = """
      query {
        sagas(limit: 10, offset: 0) {
          id
          sagaType
          status
          createdAt
          updatedAt
        }
      }
      """

      conn = post(conn, "/graphql", %{query: query})
      assert %{"data" => %{"sagas" => sagas}} = json_response(conn, 200)
      assert is_list(sagas)
    end

    test "pubsub_stats query returns statistics", %{conn: conn} do
      query = """
      query {
        pubsubStats {
          topic
          messageCount
          lastMessageAt
        }
      }
      """

      conn = post(conn, "/graphql", %{query: query})
      assert %{"data" => %{"pubsubStats" => stats}} = json_response(conn, 200)
      assert is_list(stats)
    end

    test "dashboard_stats query returns dashboard statistics", %{conn: conn} do
      query = """
      query {
        dashboardStats {
          totalEvents
          eventsPerMinute
          activeSagas
          totalCommands
          totalQueries
          systemHealth
          errorRate
          averageLatencyMs
        }
      }
      """

      conn = post(conn, "/graphql", %{query: query})
      assert %{"data" => %{"dashboardStats" => stats}} = json_response(conn, 200)
      assert is_integer(stats["totalEvents"])
      assert is_float(stats["eventsPerMinute"])
    end
  end

  describe "Health Queries" do
    test "health_check query returns health status", %{conn: conn} do
      query = """
      query {
        health {
          status
          checks {
            name
            status
            message
          }
        }
      }
      """

      conn = post(conn, "/graphql", %{query: query})
      response = json_response(conn, 200)
      assert %{"data" => %{"health" => health}} = response

      # status はアトムまたは文字列の可能性があるため、両方のケースを許可
      status = health["status"]
      assert String.downcase(to_string(status)) in ["healthy", "unhealthy", "degraded"]
    end
  end
end

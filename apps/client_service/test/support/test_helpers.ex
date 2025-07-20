defmodule ClientService.TestHelpers do
  @moduledoc """
  共通テストヘルパー関数
  """
  
  import ExUnit.Assertions
  alias ClientService.Auth.Guardian
  
  @doc """
  テスト用の認証済みコネクションを作成
  
  ## Examples
  
      conn = build_auth_conn(:admin)
      conn = build_auth_conn(:writer, %{custom_field: "value"})
      conn = build_auth_conn(%{id: "123", email: "test@example.com", role: :reader})
  """
  def build_auth_conn(role_or_user, extra_claims \\ %{})
  
  def build_auth_conn(role, extra_claims) when is_atom(role) do
    user = build_user(role)
    build_auth_conn(user, extra_claims)
  end
  
  def build_auth_conn(%{} = user, extra_claims) do
    {:ok, token, _claims} = Guardian.encode_and_sign(user, extra_claims)
    
    Phoenix.ConnTest.build_conn()
    |> Phoenix.ConnTest.put_req_header("authorization", "Bearer #{token}")
    |> Phoenix.ConnTest.put_req_header("content-type", "application/json")
  end
  
  @doc """
  テスト用ユーザーを生成
  
  ## Examples
  
      user = build_user(:admin)
      user = build_user(:writer, %{custom_field: "value"})
  """
  def build_user(role, attrs \\ %{}) when is_atom(role) do
    base_attrs = %{
      id: "test-#{role}-#{System.unique_integer([:positive])}",
      email: "#{role}@example.com",
      role: role
    }
    
    Map.merge(base_attrs, attrs)
  end
  
  @doc """
  GraphQL クエリを実行
  
  ## Examples
  
      {:ok, response} = execute_query(conn, "query { categories { id name } }")
      {:error, errors} = execute_query(conn, "invalid query")
  """
  def execute_query(conn, query, variables \\ %{}) do
    conn = Phoenix.ConnTest.post(conn, "/graphql", %{
      "query" => query,
      "variables" => variables
    })
    
    case Phoenix.ConnTest.json_response(conn, 200) do
      %{"data" => data, "errors" => nil} -> {:ok, data}
      %{"data" => data} -> {:ok, data}
      %{"errors" => errors} -> {:error, errors}
    end
  end
  
  @doc """
  GraphQL ミューテーションを実行
  """
  def execute_mutation(conn, mutation, variables \\ %{}) do
    execute_query(conn, mutation, variables)
  end
  
  @doc """
  特定のフィールドを持つエラーを探す
  
  ## Examples
  
      assert has_error_message?(errors, "認証が必要です")
      assert has_error_field?(errors, "email")
  """
  def has_error_message?(errors, message) when is_list(errors) do
    Enum.any?(errors, fn error ->
      String.contains?(error["message"] || "", message)
    end)
  end
  
  def has_error_field?(errors, field) when is_list(errors) do
    Enum.any?(errors, fn error ->
      get_in(error, ["extensions", "field"]) == field ||
      get_in(error, ["field"]) == field
    end)
  end
  
  @doc """
  認証エラーをアサート
  """
  def assert_auth_error({:error, errors}) do
    assert has_error_message?(errors, "認証") || 
           has_error_message?(errors, "Authentication") ||
           has_error_message?(errors, "権限") ||
           has_error_message?(errors, "permission")
  end
  
  def assert_auth_error(_), do: flunk("Expected authentication error")
  
  @doc """
  成功レスポンスをアサート
  """
  def assert_success_response({:ok, data}) do
    assert is_map(data)
    data
  end
  
  def assert_success_response(_), do: flunk("Expected successful response")
  
  @doc """
  フィールドの存在をアサート
  """
  def assert_field_exists(data, field_path) when is_binary(field_path) do
    assert_field_exists(data, String.split(field_path, "."))
  end
  
  def assert_field_exists(data, field_path) when is_list(field_path) do
    value = get_in(data, field_path)
    refute is_nil(value), "Expected field #{Enum.join(field_path, ".")} to exist"
    value
  end
  
  @doc """
  リスト型のレスポンスをアサート
  """
  def assert_list_response(data, field) do
    list = Map.get(data, field)
    assert is_list(list), "Expected #{field} to be a list"
    list
  end
  
  @doc """
  空でないリストをアサート
  """
  def assert_non_empty_list(data, field) do
    list = assert_list_response(data, field)
    assert length(list) > 0, "Expected #{field} to be non-empty"
    list
  end
  
  @doc """
  テスト用のカテゴリ作成ミューテーション
  """
  def create_test_category(conn, name \\ nil) do
    name = name || "Test Category #{System.unique_integer([:positive])}"
    
    mutation = """
    mutation CreateCategory($input: CreateCategoryInput!) {
      createCategory(input: $input) {
        id
        name
        description
      }
    }
    """
    
    variables = %{
      "input" => %{
        "name" => name,
        "description" => "Test category description"
      }
    }
    
    execute_mutation(conn, mutation, variables)
  end
  
  @doc """
  テスト用の商品作成ミューテーション
  """
  def create_test_product(conn, category_id, name \\ nil) do
    name = name || "Test Product #{System.unique_integer([:positive])}"
    
    mutation = """
    mutation CreateProduct($input: CreateProductInput!) {
      createProduct(input: $input) {
        id
        name
        price
        stock
      }
    }
    """
    
    variables = %{
      "input" => %{
        "name" => name,
        "price" => "99.99",
        "stock" => 100,
        "categoryId" => category_id
      }
    }
    
    execute_mutation(conn, mutation, variables)
  end
  
  @doc """
  テスト用の注文作成ミューテーション
  """
  def create_test_order(conn, items) do
    mutation = """
    mutation CreateOrder($input: CreateOrderInput!) {
      createOrder(input: $input) {
        success
        order {
          id
          userId
          status
          totalAmount
        }
        message
      }
    }
    """
    
    variables = %{
      "input" => %{
        "userId" => "test-user",
        "items" => items
      }
    }
    
    execute_mutation(conn, mutation, variables)
  end
  
  @doc """
  タイムアウトまで条件を待つ
  """
  def wait_for(condition_fn, timeout \\ 5000, interval \\ 100) do
    deadline = System.monotonic_time(:millisecond) + timeout
    
    wait_until(condition_fn, deadline, interval)
  end
  
  defp wait_until(condition_fn, deadline, interval) do
    if condition_fn.() do
      :ok
    else
      now = System.monotonic_time(:millisecond)
      
      if now < deadline do
        Process.sleep(interval)
        wait_until(condition_fn, deadline, interval)
      else
        {:error, :timeout}
      end
    end
  end
end
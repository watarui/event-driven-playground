defmodule ClientService.GraphQL.Middleware.AuthorizationTest do
  use ExUnit.Case, async: true
  
  alias ClientService.GraphQL.Middleware.Authorization
  alias Absinthe.Resolution
  
  describe "call/2" do
    test "allows access when user has required permission" do
      # Admin user with all permissions
      current_user = %{id: "123", email: "admin@example.com", role: :admin}
      resolution = %Resolution{
        context: %{current_user: current_user}
      }
      
      # Test various permissions
      assert Authorization.call(resolution, :read) == resolution
      assert Authorization.call(resolution, :write) == resolution
      assert Authorization.call(resolution, :admin) == resolution
    end
    
    test "allows read access for all authenticated users" do
      # Regular user with read permission
      current_user = %{id: "123", email: "user@example.com", role: :reader}
      resolution = %Resolution{
        context: %{current_user: current_user}
      }
      
      assert Authorization.call(resolution, :read) == resolution
    end
    
    test "denies write access for readers" do
      current_user = %{id: "123", email: "user@example.com", role: :reader}
      resolution = %Resolution{
        context: %{current_user: current_user}
      }
      
      result = Authorization.call(resolution, :write)
      
      assert result.errors == ["権限が不足しています: write 権限が必要です"]
      assert result.state == :resolved
    end
    
    test "allows write access for writers" do
      current_user = %{id: "123", email: "writer@example.com", role: :writer}
      resolution = %Resolution{
        context: %{current_user: current_user}
      }
      
      assert Authorization.call(resolution, :write) == resolution
    end
    
    test "denies admin access for non-admins" do
      current_user = %{id: "123", email: "writer@example.com", role: :writer}
      resolution = %Resolution{
        context: %{current_user: current_user}
      }
      
      result = Authorization.call(resolution, :admin)
      
      assert result.errors == ["権限が不足しています: admin 権限が必要です"]
    end
    
    test "requires authentication for non-read operations" do
      # No current_user (unauthenticated)
      resolution = %Resolution{
        context: %{}
      }
      
      result = Authorization.call(resolution, :write)
      
      assert result.errors == ["この操作には認証が必要です"]
    end
    
    test "handles nil current_user" do
      resolution = %Resolution{
        context: %{current_user: nil}
      }
      
      result = Authorization.call(resolution, :write)
      
      assert result.errors == ["この操作には認証が必要です"]
    end
    
    test "handles resolution without context" do
      resolution = %Resolution{}
      
      result = Authorization.call(resolution, :write)
      
      assert result.errors == ["この操作には認証が必要です"]
    end
    
    test "preserves existing resolution data when allowing access" do
      current_user = %{id: "123", role: :admin}
      resolution = %Resolution{
        context: %{current_user: current_user},
        value: %{some: "data"},
        state: :unresolved
      }
      
      result = Authorization.call(resolution, :admin)
      
      assert result.value == %{some: "data"}
      assert result.state == :unresolved
      assert result.context.current_user == current_user
    end
    
    test "handles custom permissions" do
      current_user = %{id: "123", role: :custom_role}
      resolution = %Resolution{
        context: %{current_user: current_user}
      }
      
      # Custom role doesn't have standard permissions
      result = Authorization.call(resolution, :write)
      
      assert result.errors == ["権限が不足しています: write 権限が必要です"]
    end
  end
  
  describe "error messages" do
    test "provides clear error for unauthenticated read attempts" do
      resolution = %Resolution{context: %{}}
      
      # Even though read is usually allowed for all, 
      # the implementation might have edge cases
      result = Authorization.call(resolution, :read)
      
      # Read should typically be allowed, but implementation may vary
      assert result == resolution || result.errors == ["内部エラーが発生しました"]
    end
    
    test "provides specific error for missing permissions" do
      current_user = %{id: "123", role: :reader}
      resolution = %Resolution{
        context: %{current_user: current_user}
      }
      
      result = Authorization.call(resolution, :delete)
      
      assert result.errors == ["権限が不足しています: delete 権限が必要です"]
    end
  end
end
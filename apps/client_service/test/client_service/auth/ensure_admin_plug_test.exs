defmodule ClientService.Auth.EnsureAdminPlugTest do
  use ExUnit.Case
  use Plug.Test

  alias ClientService.Auth.EnsureAdminPlug

  setup do
    conn = conn(:get, "/test")
    {:ok, conn: conn}
  end

  describe "call/2" do
    test "allows request when user is admin", %{conn: conn} do
      # Simulate admin user
      conn =
        conn
        |> assign(:user_signed_in?, true)
        |> assign(:current_user, %{id: "123", email: "admin@example.com", role: :admin})

      result_conn = EnsureAdminPlug.call(conn, %{})

      # Should not halt the connection
      refute result_conn.halted
      assert result_conn.status != 403
    end

    test "halts request with 403 when user is not admin", %{conn: conn} do
      # Simulate regular user
      conn =
        conn
        |> assign(:user_signed_in?, true)
        |> assign(:current_user, %{id: "123", email: "user@example.com", role: :reader})

      result_conn = EnsureAdminPlug.call(conn, %{})

      # Should halt with 403 Forbidden
      assert result_conn.halted
      assert result_conn.status == 403

      assert Jason.decode!(result_conn.resp_body) == %{
               "error" => "Forbidden",
               "message" => "Admin privileges required"
             }
    end

    test "halts request with 401 when user is not authenticated", %{conn: conn} do
      conn = assign(conn, :user_signed_in?, false)

      result_conn = EnsureAdminPlug.call(conn, %{})

      # Should halt with 401 Unauthorized
      assert result_conn.halted
      assert result_conn.status == 401

      assert Jason.decode!(result_conn.resp_body) == %{
               "error" => "Unauthorized",
               "message" => "Authentication required"
             }
    end

    test "allows request for writer role", %{conn: conn} do
      # Simulate writer user
      conn =
        conn
        |> assign(:user_signed_in?, true)
        |> assign(:current_user, %{id: "123", email: "writer@example.com", role: :writer})

      result_conn = EnsureAdminPlug.call(conn, %{})

      # Writers should also be allowed (they have write permissions)
      refute result_conn.halted
    end

    test "halts request when current_user is nil", %{conn: conn} do
      conn =
        conn
        |> assign(:user_signed_in?, true)
        |> assign(:current_user, nil)

      result_conn = EnsureAdminPlug.call(conn, %{})

      assert result_conn.halted
      assert result_conn.status == 403
    end

    test "halts request when role is missing", %{conn: conn} do
      conn =
        conn
        |> assign(:user_signed_in?, true)
        |> assign(:current_user, %{id: "123", email: "user@example.com"})

      result_conn = EnsureAdminPlug.call(conn, %{})

      assert result_conn.halted
      assert result_conn.status == 403
    end

    test "respects custom error handler for unauthorized", %{conn: conn} do
      error_handler = fn conn, message ->
        conn
        |> put_status(403)
        |> put_resp_content_type("text/plain")
        |> send_resp(403, "Custom: #{message}")
      end

      conn =
        conn
        |> assign(:user_signed_in?, true)
        |> assign(:current_user, %{id: "123", role: :reader})

      result_conn = EnsureAdminPlug.call(conn, %{error_handler: error_handler})

      assert result_conn.halted
      assert result_conn.status == 403
      assert result_conn.resp_body == "Custom: Admin access required"
    end
  end

  describe "init/1" do
    test "returns options unchanged" do
      opts = %{required_role: :super_admin}
      assert EnsureAdminPlug.init(opts) == opts
    end

    test "returns empty list when no options provided" do
      assert EnsureAdminPlug.init([]) == []
    end
  end
end

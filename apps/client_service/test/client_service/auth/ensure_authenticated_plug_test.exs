defmodule ClientService.Auth.EnsureAuthenticatedPlugTest do
  use ExUnit.Case
  use Plug.Test

  alias ClientService.Auth.EnsureAuthenticatedPlug

  setup do
    conn = conn(:get, "/test")
    {:ok, conn: conn}
  end

  describe "call/2" do
    test "allows request when user is authenticated", %{conn: conn} do
      # Simulate authenticated user
      conn = assign(conn, :user_signed_in?, true)
      conn = assign(conn, :current_user, %{id: "123", email: "test@example.com"})

      result_conn = EnsureAuthenticatedPlug.call(conn, %{})

      # Should not halt the connection
      refute result_conn.halted
      assert result_conn.status != 401
    end

    test "halts request with 401 when user is not authenticated", %{conn: conn} do
      # Simulate unauthenticated user
      conn = assign(conn, :user_signed_in?, false)
      conn = assign(conn, :current_user, nil)

      result_conn = EnsureAuthenticatedPlug.call(conn, %{})

      # Should halt the connection with 401
      assert result_conn.halted
      assert result_conn.status == 401

      assert Jason.decode!(result_conn.resp_body) == %{
               "error" => "Unauthorized",
               "message" => "Authentication required"
             }
    end

    test "halts request when user_signed_in? is not set", %{conn: conn} do
      # No assigns set
      result_conn = EnsureAuthenticatedPlug.call(conn, %{})

      assert result_conn.halted
      assert result_conn.status == 401
    end

    test "respects custom error handler", %{conn: conn} do
      # Define custom error handler
      error_handler = fn conn ->
        conn
        |> put_status(403)
        |> put_resp_content_type("application/json")
        |> send_resp(403, Jason.encode!(%{custom_error: "Access denied"}))
      end

      conn = assign(conn, :user_signed_in?, false)

      result_conn = EnsureAuthenticatedPlug.call(conn, %{error_handler: error_handler})

      assert result_conn.halted
      assert result_conn.status == 403

      assert Jason.decode!(result_conn.resp_body) == %{
               "custom_error" => "Access denied"
             }
    end

    test "uses correct content type", %{conn: conn} do
      conn = assign(conn, :user_signed_in?, false)

      result_conn = EnsureAuthenticatedPlug.call(conn, %{})

      assert get_resp_header(result_conn, "content-type") == ["application/json; charset=utf-8"]
    end
  end

  describe "init/1" do
    test "returns options unchanged" do
      opts = %{some: "option"}
      assert EnsureAuthenticatedPlug.init(opts) == opts
    end

    test "returns empty list when no options provided" do
      assert EnsureAuthenticatedPlug.init([]) == []
    end
  end
end

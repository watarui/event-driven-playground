defmodule ClientService.Auth.AuthPlugTest do
  use ExUnit.Case
  use Plug.Test

  alias ClientService.Auth.AuthPlug
  alias ClientService.Auth.Guardian

  @user %{
    id: "test-user-123",
    email: "test@example.com",
    role: :admin
  }

  setup do
    # Create a connection
    conn = conn(:get, "/test")
    {:ok, conn: conn}
  end

  describe "call/2" do
    test "adds user to assigns when valid token provided", %{conn: conn} do
      # Generate a valid token
      {:ok, token, _claims} = Guardian.encode_and_sign(@user)

      # Add authorization header
      conn = put_req_header(conn, "authorization", "Bearer #{token}")

      # Call the plug
      result_conn = AuthPlug.call(conn, %{})

      # Check that user is added to assigns
      assert result_conn.assigns.current_user.id == @user.id
      assert result_conn.assigns.current_user.email == @user.email
      assert result_conn.assigns.user_signed_in? == true
    end

    test "sets user_signed_in? to false when no token provided", %{conn: conn} do
      result_conn = AuthPlug.call(conn, %{})

      assert result_conn.assigns.current_user == nil
      assert result_conn.assigns.user_signed_in? == false
    end

    test "sets user_signed_in? to false when invalid token provided", %{conn: conn} do
      conn = put_req_header(conn, "authorization", "Bearer invalid.token.here")

      result_conn = AuthPlug.call(conn, %{})

      assert result_conn.assigns.current_user == nil
      assert result_conn.assigns.user_signed_in? == false
    end

    test "sets user_signed_in? to false when expired token provided", %{conn: conn} do
      # Create an expired token
      {:ok, token, _} = Guardian.encode_and_sign(@user, %{}, ttl: {0, :second})
      Process.sleep(100)

      conn = put_req_header(conn, "authorization", "Bearer #{token}")

      result_conn = AuthPlug.call(conn, %{})

      assert result_conn.assigns.current_user == nil
      assert result_conn.assigns.user_signed_in? == false
    end

    test "handles malformed authorization header gracefully", %{conn: conn} do
      # Missing "Bearer" prefix
      conn = put_req_header(conn, "authorization", "just_a_token")

      result_conn = AuthPlug.call(conn, %{})

      assert result_conn.assigns.current_user == nil
      assert result_conn.assigns.user_signed_in? == false
    end

    test "extracts token from cookie if no authorization header", %{conn: conn} do
      {:ok, token, _claims} = Guardian.encode_and_sign(@user)

      # Add token to cookies instead of header
      conn = put_req_cookie(conn, "auth_token", token)

      result_conn = AuthPlug.call(conn, %{})

      assert result_conn.assigns.current_user.id == @user.id
      assert result_conn.assigns.user_signed_in? == true
    end

    test "prioritizes authorization header over cookie", %{conn: conn} do
      # Create two different users
      user1 = %{id: "user1", email: "user1@example.com", role: :reader}
      user2 = %{id: "user2", email: "user2@example.com", role: :admin}

      {:ok, token1, _} = Guardian.encode_and_sign(user1)
      {:ok, token2, _} = Guardian.encode_and_sign(user2)

      # Add different tokens to header and cookie
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token1}")
        |> put_req_cookie("auth_token", token2)

      result_conn = AuthPlug.call(conn, %{})

      # Should use the token from header (user1)
      assert result_conn.assigns.current_user.id == user1.id
    end
  end

  describe "init/1" do
    test "returns options unchanged" do
      opts = %{some: "option"}
      assert AuthPlug.init(opts) == opts
    end
  end
end

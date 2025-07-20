defmodule ClientService.Auth.GuardianTest do
  use ExUnit.Case, async: true

  alias ClientService.Auth.Guardian

  @user %{
    id: "test-user-123",
    email: "test@example.com",
    role: :admin
  }

  describe "encode_and_sign/3" do
    test "creates a valid JWT token" do
      assert {:ok, token, claims} = Guardian.encode_and_sign(@user)
      assert is_binary(token)
      assert claims["sub"] == @user.id
      assert claims["typ"] == "access"
    end

    test "creates token with custom claims" do
      custom_claims = %{"custom_field" => "custom_value"}
      assert {:ok, _token, claims} = Guardian.encode_and_sign(@user, custom_claims)
      assert claims["custom_field"] == "custom_value"
    end

    test "creates token with custom token type" do
      assert {:ok, _token, claims} = Guardian.encode_and_sign(@user, %{}, token_type: "refresh")
      assert claims["typ"] == "refresh"
    end
  end

  describe "decode_and_verify/2" do
    test "verifies and decodes a valid token" do
      {:ok, token, _} = Guardian.encode_and_sign(@user)
      assert {:ok, claims} = Guardian.decode_and_verify(token)
      assert claims["sub"] == @user.id
    end

    test "rejects invalid token" do
      assert {:error, :invalid_token} = Guardian.decode_and_verify("invalid.token.here")
    end

    test "rejects expired token" do
      # Create a token that expires immediately
      {:ok, token, _} = Guardian.encode_and_sign(@user, %{}, ttl: {0, :second})
      Process.sleep(100)
      assert {:error, :token_expired} = Guardian.decode_and_verify(token)
    end
  end

  describe "resource_from_claims/1" do
    test "extracts user from valid claims" do
      {:ok, _token, claims} = Guardian.encode_and_sign(@user)
      assert {:ok, resource} = Guardian.resource_from_claims(claims)
      assert resource.id == @user.id
      assert resource.email == @user.email
      assert resource.role == @user.role
    end

    test "returns error for invalid claims" do
      assert {:error, :invalid_claims} = Guardian.resource_from_claims(%{})
      assert {:error, :invalid_claims} = Guardian.resource_from_claims(%{"sub" => nil})
    end
  end

  describe "subject_for_token/2" do
    test "returns user id as subject" do
      assert {:ok, subject, _claims} = Guardian.subject_for_token(@user, %{})
      assert subject == @user.id
    end

    test "returns error for invalid resource" do
      assert {:error, :invalid_resource} = Guardian.subject_for_token(%{}, %{})
      assert {:error, :invalid_resource} = Guardian.subject_for_token(nil, %{})
    end
  end

  describe "build_claims/3" do
    test "builds default claims" do
      assert {:ok, claims} = Guardian.build_claims(%{}, @user, %{})
      assert claims["aud"] == "client_service"
      assert claims["iss"] == "client_service"
      assert is_integer(claims["exp"])
      assert is_integer(claims["iat"])
      assert is_integer(claims["nbf"])
    end

    test "includes user information in claims" do
      assert {:ok, claims} = Guardian.build_claims(%{}, @user, %{})
      assert claims["email"] == @user.email
      assert claims["role"] == to_string(@user.role)
    end
  end

  describe "refresh/2" do
    test "creates new token from existing valid token" do
      {:ok, old_token, old_claims} = Guardian.encode_and_sign(@user)

      assert {:ok, _old_claims, {new_token, new_claims}} = Guardian.refresh(old_token)
      assert is_binary(new_token)
      assert new_token != old_token
      assert new_claims["sub"] == old_claims["sub"]
    end
  end

  describe "revoke/2" do
    test "revokes a token" do
      {:ok, token, claims} = Guardian.encode_and_sign(@user)
      assert {:ok, _claims} = Guardian.revoke(token)

      # In a real implementation, you would check if the token is blacklisted
      # For now, we just verify the operation doesn't fail
    end
  end
end

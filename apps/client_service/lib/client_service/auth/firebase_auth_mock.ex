defmodule ClientService.Auth.FirebaseAuthMock do
  @moduledoc """
  テスト用の Firebase 認証モックアダプター
  """

  @behaviour ClientService.Auth.FirebaseAuthBehaviour

  require Logger

  @impl true
  def verify_token(token) do
    Logger.info("MockFirebaseAuth.verify_token called with token: #{String.slice(token, 0, 20)}...")

    case parse_mock_token(token) do
      {:ok, claims} ->
        # メール認証チェック
        if Map.get(claims, "email_verified", true) == false do
          {:error, :email_not_verified}
        else
          {:ok, build_user_info(claims)}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def build_user_info(claims) do
    email = Map.get(claims, "email")
    role = get_user_role(claims)

    %{
      user_id: Map.get(claims, "sub", "test-user-123"),
      email: email,
      email_verified: Map.get(claims, "email_verified", true),
      name: Map.get(claims, "name"),
      picture: Map.get(claims, "picture"),
      role: role,
      roles: get_custom_claims(claims, "roles", []),
      is_admin: role == :admin,
      claims: claims
    }
  end

  @impl true
  def get_user_role(claims) do
    # カスタムクレームのロールを優先
    custom_role = get_custom_claims(claims, "role", nil)
    
    if custom_role do
      String.to_atom(custom_role)
    else
      # メールベースのロール判定
      case Map.get(claims, "email") do
        "admin@example.com" -> :admin
        "writer@example.com" -> :writer
        _ -> :reader
      end
    end
  end

  # Private functions

  defp parse_mock_token(token) do
    case token do
      "valid.firebase.token" ->
        {:ok, %{
          "sub" => "firebase-user-123",
          "email" => "user@example.com",
          "email_verified" => true,
          "name" => "Test User"
        }}

      "admin.token" ->
        {:ok, %{
          "sub" => "admin-user-123",
          "email" => "admin@example.com",
          "email_verified" => true,
          "name" => "Admin User"
        }}

      "writer.token" ->
        {:ok, %{
          "sub" => "writer-user-123",
          "email" => "writer@example.com",
          "email_verified" => true,
          "name" => "Writer User"
        }}

      "custom.claims.token" ->
        {:ok, %{
          "sub" => "custom-user-123",
          "email" => "user@example.com",
          "email_verified" => true,
          "custom_claims" => %{"role" => "admin"}
        }}

      "unverified.token" ->
        {:ok, %{
          "sub" => "unverified-user-123",
          "email" => "unverified@example.com",
          "email_verified" => false
        }}

      "no.email.token" ->
        {:ok, %{
          "sub" => "no-email-user-123",
          "email_verified" => true
        }}

      "cached.token" ->
        {:ok, %{
          "sub" => "cached-user-123",
          "email" => "cached@example.com",
          "email_verified" => true
        }}

      "expired.token" ->
        {:error, :token_expired}

      "invalid.token" ->
        {:error, :invalid_token}

      _ ->
        # その他のトークンはエラーとして扱う
        {:error, :invalid_token_format}
    end
  end

  defp get_custom_claims(claims, key, default) do
    claims
    |> Map.get("custom_claims", %{})
    |> Map.get(key, default)
  end
end
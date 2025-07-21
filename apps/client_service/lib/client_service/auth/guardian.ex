defmodule ClientService.Auth.Guardian do
  @moduledoc """
  Firebase Authentication との連携モジュール
  Guardian のインターフェースを維持しつつ Firebase Auth を使用
  """
  use Guardian, otp_app: :client_service
  require Logger

  alias ClientService.Auth.FirebaseAuth

  @doc """
  JWT からサブジェクトを取得
  """
  @impl Guardian
  def subject_for_token(resource, _claims) do
    case resource do
      %{user_id: user_id} when not is_nil(user_id) ->
        {:ok, to_string(user_id)}
      
      %{id: id} when not is_nil(id) ->
        {:ok, to_string(id)}
      
      _ ->
        {:error, :invalid_resource}
    end
  end

  @doc """
  JWT のサブジェクトからリソースを取得
  """
  @impl Guardian
  def resource_from_claims(claims) do
    Logger.info("Guardian.resource_from_claims called with: #{inspect(claims)}")

    # Firebase の claims からユーザー情報を構築
    case claims do
      %{"sub" => id} when not is_nil(id) ->
        user_info = FirebaseAuth.build_user_info(claims)
        Logger.info("Built user info: #{inspect(user_info)}")
        {:ok, user_info}

      _ ->
        Logger.error("Invalid claims: #{inspect(claims)}")
        {:error, :invalid_claims}
    end
  end

  @doc """
  Firebase JWT の検証
  Guardian インターフェース互換
  """
  def verify_token(token) do
    FirebaseAuth.verify_token(token)
  end

  # Guardian の verify_claims をオーバーライド
  @impl Guardian
  def verify_claims(claims, _opts) do
    Logger.info("Guardian.verify_claims called with claims: #{inspect(claims)}")
    {:ok, claims}
  end

  @doc """
  Guardian Plug が使用するトークンのタイプ
  """
  def default_token_type, do: "access"

  @doc """
  トークンからタイプを取得
  """
  def get_token_type(%{"typ" => type}), do: type
  def get_token_type(_), do: "access"

  @doc """
  クレームを構築
  Guardian のデフォルト実装をオーバーライド
  """
  @impl Guardian
  def build_claims(claims, resource, opts) do
    Logger.info("Guardian.build_claims called with resource: #{inspect(resource)}")
    
    # 基本的なクレームを構築
    new_claims = %{
      "aud" => "client_service",
      "typ" => (if is_list(opts), do: Keyword.get(opts, :token_type, "access"), else: Map.get(opts, :token_type, "access")),
      "iss" => "client_service"
    }
    
    # リソースから追加のクレームを抽出
    resource_claims = 
      case resource do
        %{email: email, role: role} when not is_nil(email) ->
          %{
            "email" => email,
            "role" => to_string(role)
          }
        _ ->
          %{}
      end
    
    # すべてのクレームをマージ
    {:ok, Map.merge(claims, Map.merge(new_claims, resource_claims))}
  end
end

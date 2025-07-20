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
    sub = to_string(resource.user_id || resource.id)
    {:ok, sub}
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
end

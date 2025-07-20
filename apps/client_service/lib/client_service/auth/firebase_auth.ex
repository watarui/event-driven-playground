defmodule ClientService.Auth.FirebaseAuth do
  @moduledoc """
  Firebase Authentication JWT トークンの検証
  """
  @behaviour ClientService.Auth.FirebaseAuthBehaviour

  require Logger

  @firebase_public_keys_url "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com"
  @cache_duration :timer.hours(1)

  # アダプターの取得
  defp adapter do
    Application.get_env(:client_service, :firebase_auth_adapter, __MODULE__)
  end

  @doc """
  Firebase JWT トークンを検証
  """
  @impl true
  def verify_token(token) do
    # テスト環境ではアダプターに委譲
    if adapter() != __MODULE__ do
      adapter().verify_token(token)
    else
      # 本番環境では通常の検証を実行
      Logger.info("Firebase token verification started")
      Logger.debug("Token received: #{String.slice(token, 0, 50)}...")

      with {:ok, header, claims} <- decode_token(token),
           :ok <- validate_header(header),
           :ok <- validate_claims(claims),
           {:ok, key_id} <- get_key_id(header),
           {:ok, public_key} <- get_public_key(key_id),
           :ok <- verify_signature(token, public_key) do
        Logger.info("Firebase token verification succeeded for user: #{claims["sub"]}")
        {:ok, build_user_info(claims)}
      else
        {:error, reason} ->
          Logger.error("Firebase token verification failed: #{inspect(reason)}")
          {:error, :unauthorized}
      end
    end
  end

  @doc """
  トークンからユーザー情報を構築
  """
  @impl true
  def build_user_info(claims) do
    email = claims["email"]
    role = Shared.Auth.Permissions.determine_role(email)

    %{
      user_id: claims["sub"],
      email: email,
      email_verified: claims["email_verified"] || false,
      name: claims["name"],
      picture: claims["picture"],
      role: role,
      roles: get_custom_claims(claims, "roles", []),
      is_admin: role == :admin,
      claims: claims
    }
  end

  # JWT をデコード（署名検証なし）
  defp decode_token(token) do
    case String.split(token, ".") do
      [header, payload, _signature] ->
        with {:ok, header_json} <- Base.url_decode64(header, padding: false),
             {:ok, header_data} <- Jason.decode(header_json),
             {:ok, payload_json} <- Base.url_decode64(payload, padding: false),
             {:ok, payload_data} <- Jason.decode(payload_json) do
          {:ok, header_data, payload_data}
        else
          _ -> {:error, :invalid_token_format}
        end

      _ ->
        {:error, :invalid_token_format}
    end
  end

  # ヘッダーの検証
  defp validate_header(%{"alg" => "RS256", "typ" => "JWT", "kid" => kid}) when is_binary(kid) do
    :ok
  end

  defp validate_header(_), do: {:error, :invalid_header}

  # クレームの検証
  defp validate_claims(claims) do
    project_id = get_firebase_project_id()
    now = System.system_time(:second)

    with :ok <- validate_issuer(claims, project_id),
         :ok <- validate_audience(claims, project_id),
         :ok <- validate_expiration(claims, now),
         :ok <- validate_issued_at(claims, now) do
      validate_auth_time(claims, now)
    end
  end

  defp validate_issuer(%{"iss" => issuer}, project_id) do
    expected = "https://securetoken.google.com/#{project_id}"
    if issuer == expected, do: :ok, else: {:error, :invalid_issuer}
  end

  defp validate_issuer(_, _), do: {:error, :missing_issuer}

  defp validate_audience(%{"aud" => audience}, project_id) do
    if audience == project_id, do: :ok, else: {:error, :invalid_audience}
  end

  defp validate_audience(_, _), do: {:error, :missing_audience}

  defp validate_expiration(%{"exp" => exp}, now) when is_integer(exp) do
    if exp > now, do: :ok, else: {:error, :token_expired}
  end

  defp validate_expiration(_, _), do: {:error, :missing_expiration}

  defp validate_issued_at(%{"iat" => iat}, now) when is_integer(iat) do
    if iat <= now, do: :ok, else: {:error, :token_used_too_early}
  end

  defp validate_issued_at(_, _), do: {:error, :missing_issued_at}

  defp validate_auth_time(%{"auth_time" => auth_time}, now) when is_integer(auth_time) do
    if auth_time <= now, do: :ok, else: {:error, :invalid_auth_time}
  end

  # auth_time is optional
  defp validate_auth_time(_, _), do: :ok

  # ヘッダーから key ID を取得
  defp get_key_id(%{"kid" => kid}) when is_binary(kid), do: {:ok, kid}
  defp get_key_id(_), do: {:error, :missing_key_id}

  # 公開鍵の取得（キャッシュ付き）
  defp get_public_key(key_id) do
    case Cachex.get(:firebase_keys, key_id) do
      {:ok, nil} ->
        fetch_and_cache_keys(key_id)

      {:ok, key} ->
        {:ok, key}

      _ ->
        fetch_and_cache_keys(key_id)
    end
  end

  defp fetch_and_cache_keys(key_id) do
    with {:ok, %{status_code: 200, body: body}} <- HTTPoison.get(@firebase_public_keys_url),
         {:ok, keys} <- Jason.decode(body),
         {:ok, key_pem} <- Map.fetch(keys, key_id) do
      # すべてのキーをキャッシュ
      Enum.each(keys, fn {kid, pem} ->
        Cachex.put(:firebase_keys, kid, pem, ttl: @cache_duration)
      end)

      {:ok, key_pem}
    else
      _ -> {:error, :key_not_found}
    end
  end

  # 署名の検証
  defp verify_signature(token, public_key_pem) do
    try do
      # PEM を JWK に変換
      jwk = JOSE.JWK.from_pem(public_key_pem)

      # トークンを検証
      case JOSE.JWT.verify(jwk, token) do
        {true, _, _} ->
          Logger.info("Signature verification successful")
          :ok

        {false, _, _} ->
          Logger.error("Signature verification failed: invalid signature")
          {:error, :invalid_signature}
      end
    rescue
      e ->
        Logger.error("Signature verification error: #{inspect(e)}")
        {:error, :signature_verification_failed}
    end
  end

  # カスタムクレームの取得
  defp get_custom_claims(claims, key, default) do
    claims
    |> Map.get("custom_claims", %{})
    |> Map.get(key, default)
  end

  @doc """
  ユーザーのロールを取得
  """
  @impl true
  def get_user_role(claims) do
    # テスト環境ではアダプターに委譲
    if adapter() != __MODULE__ do
      adapter().get_user_role(claims)
    else
      Shared.Auth.Permissions.determine_role(claims)
    end
  end

  # Firebase プロジェクト ID の取得
  defp get_firebase_project_id do
    project_id =
      System.get_env("FIREBASE_PROJECT_ID") ||
        Application.get_env(:client_service, :firebase_project_id)

    Logger.debug("Firebase project ID: #{inspect(project_id)}")
    project_id
  end
end

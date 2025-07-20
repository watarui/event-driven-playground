defmodule Shared.Config do
  @moduledoc """
  共通設定管理モジュール
  
  各サービスで重複している設定を一元管理します。
  環境固有の設定は config/environments/*.exs から読み込みます。
  """

  @doc """
  環境固有の設定を取得
  """
  @spec get_env_config(atom(), any()) :: any()
  def get_env_config(key, default \\ nil) do
    Application.get_env(:shared, key, default)
  end

  @doc """
  ネストした設定値を取得
  """
  @spec get_env_config(atom(), atom(), any()) :: any()
  def get_env_config(key, nested_key, default) do
    case Application.get_env(:shared, key) do
      nil -> default
      config when is_map(config) -> Map.get(config, nested_key, default)
      config when is_list(config) -> Keyword.get(config, nested_key, default)
      _ -> default
    end
  end

  @doc """
  データベース URL を取得
  
  サービス固有の環境変数を優先し、なければ共通の DATABASE_URL を使用
  """
  @spec database_url(atom()) :: String.t() | nil
  def database_url(service) when is_atom(service) do
    service_env = "#{String.upcase(to_string(service))}_DATABASE_URL"
    System.get_env(service_env) || System.get_env("DATABASE_URL")
  end

  @doc """
  データベース接続の SSL オプションを取得
  """
  @spec ssl_opts() :: Keyword.t()
  def ssl_opts do
    [
      verify: :verify_none,
      cacerts: :public_key.cacerts_get()
    ]
  end

  @doc """
  データベース接続の共通設定を取得
  """
  @spec database_config(atom()) :: Keyword.t() | no_return()
  def database_config(service) do
    url = database_url(service)
    
    if url do
      config = Ecto.Repo.Supervisor.parse_url(url)
      db_config = get_env_config(:database, %{})
      
      Keyword.merge(config, [
        ssl: Map.get(db_config, :ssl, true),
        ssl_opts: Map.get(db_config, :ssl_opts, ssl_opts()),
        pool_size: String.to_integer(System.get_env("POOL_SIZE") || to_string(Map.get(db_config, :pool_size, 2))),
        socket_options: [:inet6],
        show_sensitive_data_on_connection_error: Map.get(db_config, :show_sensitive_data_on_connection_error, false),
        queue_target: Map.get(db_config, :queue_target, 5000),
        queue_interval: Map.get(db_config, :queue_interval, 1000),
        timeout: Map.get(db_config, :timeout, 15_000)
      ])
    else
      raise """
      Database URL not configured for service: #{service}
      
      Please set either #{String.upcase(to_string(service))}_DATABASE_URL or DATABASE_URL
      """
    end
  end

  @doc """
  Phoenix エンドポイントの共通設定を取得
  """
  @spec endpoint_config(Keyword.t()) :: Keyword.t()
  def endpoint_config(opts \\ []) do
    port = String.to_integer(System.get_env("PORT") || "8080")
    phoenix_config = get_env_config(:phoenix, %{})
    
    base_config = [
      server: true,
      http: [
        ip: {0, 0, 0, 0},
        port: port
      ],
      url: [
        host: System.get_env("PHX_HOST") || "localhost",
        port: 443,
        scheme: "https"
      ],
      check_origin: Map.get(phoenix_config, :check_origin, false),
      secret_key_base: secret_key_base(),
      gzip: Map.get(phoenix_config, :gzip, false),
      force_ssl: Map.get(phoenix_config, :force_ssl, false)
    ]
    
    # Add static cache control if configured
    final_config = 
      if cache_control = Map.get(phoenix_config, :static_cache_control) do
        Keyword.put(base_config, :static_cache_control, cache_control)
      else
        base_config
      end
    
    Keyword.merge(final_config, opts)
  end

  @doc """
  PubSub の設定を取得
  """
  @spec pubsub_config() :: Keyword.t()
  def pubsub_config do
    [
      project_id: System.get_env("GOOGLE_CLOUD_PROJECT"),
      emulator_host: System.get_env("PUBSUB_EMULATOR_HOST")
    ]
  end

  @doc """
  Google Cloud 環境かどうかを判定
  """
  @spec cloud_environment?() :: boolean()
  def cloud_environment? do
    System.get_env("GOOGLE_CLOUD_PROJECT") != nil ||
      System.get_env("CLOUD_RUN_SERVICE_URL") != nil
  end

  @doc """
  EventBus モジュールを取得
  """
  @spec event_bus_module() :: module()
  def event_bus_module do
    Shared.Infrastructure.EventBus
  end

  @doc """
  Firebase 設定を取得（Client Service のみ）
  """
  @spec firebase_config() :: map() | nil
  def firebase_config do
    api_key = System.get_env("FIREBASE_API_KEY")
    
    if api_key do
      %{
        api_key: api_key,
        auth_domain: System.get_env("FIREBASE_AUTH_DOMAIN"),
        project_id: System.get_env("FIREBASE_PROJECT_ID"),
        private_key_id: System.get_env("FIREBASE_PRIVATE_KEY_ID"),
        private_key: System.get_env("FIREBASE_PRIVATE_KEY"),
        client_email: System.get_env("FIREBASE_CLIENT_EMAIL"),
        client_id: System.get_env("FIREBASE_CLIENT_ID"),
        auth_uri: System.get_env("FIREBASE_AUTH_URI"),
        token_uri: System.get_env("FIREBASE_TOKEN_URI"),
        auth_provider_x509_cert_url: System.get_env("FIREBASE_AUTH_PROVIDER_X509_CERT_URL"),
        client_x509_cert_url: System.get_env("FIREBASE_CLIENT_X509_CERT_URL")
      }
    else
      nil
    end
  end

  # プライベート関数

  @spec secret_key_base() :: String.t() | no_return()
  defp secret_key_base do
    System.get_env("SECRET_KEY_BASE") ||
      raise("""
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """)
  end
end
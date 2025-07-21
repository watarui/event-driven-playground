defmodule Shared.Infrastructure.Firestore.Client do
  @moduledoc """
  Firestore クライアントの設定と接続管理
  
  開発環境では Emulator、本番環境では実際の Firestore に接続します。
  """

  require Logger

  @doc """
  Firestore 接続を取得
  
  サービスごとに異なるプロジェクトID を使用可能にします。
  """
  def get_connection(_service \\ :shared) do
    # Goth で認証トークンを取得
    case get_auth_token() do
      {:ok, token} ->
        # GoogleApi.Firestore.V1.Connection を作成
        {:ok, GoogleApi.Firestore.V1.Connection.new(token)}
        
      {:error, reason} ->
        Logger.error("Failed to get auth token: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  プロジェクトID を取得
  """
  def get_project_id(service) do
    env_key = 
      case service do
        :event_store -> "FIRESTORE_PROJECT_ID_EVENT_STORE"
        :command -> "FIRESTORE_PROJECT_ID_COMMAND"
        :query -> "FIRESTORE_PROJECT_ID_QUERY"
        _ -> "FIRESTORE_PROJECT_ID"
      end
    
    System.get_env(env_key) || default_project_id(service)
  end

  @doc """
  Emulator のホストを取得
  """
  def get_emulator_host(service) do
    env_key = 
      case service do
        :event_store -> "FIRESTORE_EMULATOR_HOST_EVENT_STORE"
        :command -> "FIRESTORE_EMULATOR_HOST_COMMAND"
        :query -> "FIRESTORE_EMULATOR_HOST_QUERY"
        _ -> "FIRESTORE_EMULATOR_HOST"
      end
    
    System.get_env(env_key)
  end

  @doc """
  Emulator を使用しているかチェック
  """
  def using_emulator?(service) do
    get_emulator_host(service) != nil
  end

  # Private functions

  defp get_auth_token do
    if using_emulator?(:any) do
      # Emulator では認証不要
      {:ok, "emulator-token"}
    else
      # 本番環境では Goth で認証
      case Goth.fetch(Shared.Goth) do
        {:ok, %{token: token}} -> {:ok, token}
        error -> error
      end
    end
  end

  defp default_project_id(service) do
    if Mix.env() == :prod do
      "event-driven-playground-prod"
    else
      # 開発環境では各サービスごとのプロジェクトID
      case service do
        :event_store -> "event-store-local"
        :command -> "command-service-local"
        :query -> "query-service-local"
        _ -> "shared-local"
      end
    end
  end
end
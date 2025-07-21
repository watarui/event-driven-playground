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
  def get_project_id(_service) do
    System.get_env("FIRESTORE_PROJECT_ID") || "demo-project"
  end

  @doc """
  Emulator のホストを取得
  """
  def get_emulator_host(_service) do
    System.get_env("FIRESTORE_EMULATOR_HOST")
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

end
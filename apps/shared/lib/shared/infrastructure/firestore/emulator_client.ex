defmodule Shared.Infrastructure.Firestore.EmulatorClient do
  @moduledoc """
  Firestore エミュレータ用のカスタムクライアント
  
  Google API クライアントはエミュレータをサポートしていないため、
  直接 REST API を使用してエミュレータと通信します。
  """
  
  require Logger
  
  @doc """
  エミュレータ用の Tesla クライアントを作成
  """
  def create_client(service) do
    emulator_host = Shared.Infrastructure.Firestore.Client.get_emulator_host(service)
    
    if emulator_host do
      middleware = [
        {Tesla.Middleware.BaseUrl, "http://#{emulator_host}/v1"},
        Tesla.Middleware.JSON,
        {Tesla.Middleware.Headers, [{"authorization", "Bearer owner"}]},
        Tesla.Middleware.Logger
      ]
      
      Tesla.client(middleware)
    else
      nil
    end
  end
  
  @doc """
  ドキュメントを作成または更新
  """
  def create_or_update_document(client, project_id, collection, document_id, fields) do
    path = "projects/#{project_id}/databases/(default)/documents/#{collection}/#{document_id}"
    
    body = %{
      fields: convert_to_firestore_fields(fields)
    }
    
    case Tesla.patch(client, path, body, query: [updateMask_fieldPaths: "*"]) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}
      {:ok, %{status: status, body: body}} ->
        Logger.error("Firestore error: #{status} - #{inspect(body)}")
        {:error, body}
      {:error, reason} ->
        Logger.error("HTTP error: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @doc """
  ドキュメントを取得
  """
  def get_document(client, project_id, collection, document_id) do
    path = "projects/#{project_id}/databases/(default)/documents/#{collection}/#{document_id}"
    
    case Tesla.get(client, path) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}
      {:ok, %{status: 404}} ->
        {:error, :not_found}
      {:ok, %{status: status, body: body}} ->
        Logger.error("Firestore error: #{status} - #{inspect(body)}")
        {:error, body}
      {:error, reason} ->
        Logger.error("HTTP error: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @doc """
  ドキュメントのリストを取得
  """
  def list_documents(client, project_id, collection, opts \\ []) do
    path = "projects/#{project_id}/databases/(default)/documents/#{collection}"
    
    query = Keyword.take(opts, [:pageSize, :orderBy, :pageToken])
    
    case Tesla.get(client, path, query: query) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}
      {:ok, %{status: status, body: body}} ->
        Logger.error("Firestore error: #{status} - #{inspect(body)}")
        {:error, body}
      {:error, reason} ->
        Logger.error("HTTP error: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @doc """
  ドキュメントを削除
  """
  def delete_document(client, project_id, collection, document_id) do
    path = "projects/#{project_id}/databases/(default)/documents/#{collection}/#{document_id}"
    
    case Tesla.delete(client, path) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok
      {:ok, %{status: status, body: body}} ->
        Logger.error("Firestore error: #{status} - #{inspect(body)}")
        {:error, body}
      {:error, reason} ->
        Logger.error("HTTP error: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @doc """
  バッチ書き込み
  """
  def commit_writes(client, project_id, writes) do
    path = "projects/#{project_id}/databases/(default)/documents:commit"
    
    # Write オブジェクトを適切な形式に変換
    converted_writes = Enum.map(writes, fn write ->
      if Map.has_key?(write, :update) do
        # update オペレーション
        %{
          "update" => %{
            "name" => write.update.name,
            "fields" => write.update.fields
          }
        }
      else
        # その他のオペレーション（delete など）
        write
      end
    end)
    
    body = %{
      "writes" => converted_writes
    }
    
    case Tesla.post(client, path, body) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}
      {:ok, %{status: status, body: body}} ->
        Logger.error("Firestore error: #{status} - #{inspect(body)}")
        {:error, body}
      {:error, reason} ->
        Logger.error("HTTP error: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  # Elixir の値を Firestore のフィールド形式に変換
  defp convert_to_firestore_fields(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      {to_string(key), convert_to_firestore_value(value)}
    end)
  end
  
  defp convert_to_firestore_value(value) do
    cond do
      is_binary(value) -> %{stringValue: value}
      is_integer(value) -> %{integerValue: to_string(value)}
      is_float(value) -> %{doubleValue: value}
      is_boolean(value) -> %{booleanValue: value}
      is_nil(value) -> %{nullValue: "NULL_VALUE"}
      is_map(value) -> %{mapValue: %{fields: convert_to_firestore_fields(value)}}
      is_list(value) -> %{arrayValue: %{values: Enum.map(value, &convert_to_firestore_value/1)}}
      true -> %{stringValue: to_string(value)}
    end
  end
end
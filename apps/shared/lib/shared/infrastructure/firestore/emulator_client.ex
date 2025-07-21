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
      %{
        base_url: "http://#{emulator_host}/v1",
        project_id: Shared.Infrastructure.Firestore.Client.get_project_id(service)
      }
    else
      nil
    end
  end
  
  @doc """
  ドキュメントを作成または更新
  """
  def create_or_update_document(client, project_id, collection, document_id, fields) do
    url = "#{client.base_url}/projects/#{project_id}/databases/(default)/documents/#{collection}/#{document_id}"
    
    body = %{
      fields: convert_to_firestore_fields(fields)
    }
    
    headers = [
      {"Authorization", "Bearer owner"},
      {"Content-Type", "application/json"}
    ]
    
    request = Finch.build(:patch, url, headers, Jason.encode!(body))
    
    case Finch.request(request, Shared.Finch) do
      {:ok, %{status: status, body: response_body}} when status in 200..299 ->
        {:ok, Jason.decode!(response_body)}
      {:ok, %{status: status, body: response_body}} ->
        Logger.error("Firestore error: #{status} - #{response_body}")
        {:error, response_body}
      {:error, reason} ->
        Logger.error("HTTP error: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @doc """
  ドキュメントを取得
  """
  def get_document(client, project_id, collection, document_id) do
    url = "#{client.base_url}/projects/#{project_id}/databases/(default)/documents/#{collection}/#{document_id}"
    
    headers = [
      {"Authorization", "Bearer owner"},
      {"Content-Type", "application/json"}
    ]
    
    request = Finch.build(:get, url, headers)
    
    case Finch.request(request, Shared.Finch) do
      {:ok, %{status: 200, body: response_body}} ->
        {:ok, Jason.decode!(response_body)}
      {:ok, %{status: 404}} ->
        {:error, :not_found}
      {:ok, %{status: status, body: response_body}} ->
        Logger.error("Firestore error: #{status} - #{response_body}")
        {:error, response_body}
      {:error, reason} ->
        Logger.error("HTTP error: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @doc """
  ドキュメントのリストを取得
  """
  def list_documents(client, project_id, collection, opts \\ []) do
    query_params = 
      opts
      |> Keyword.take([:pageSize, :orderBy, :pageToken])
      |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
      |> Enum.join("&")
    
    query_string = if query_params == "", do: "", else: "?#{query_params}"
    url = "#{client.base_url}/projects/#{project_id}/databases/(default)/documents/#{collection}#{query_string}"
    
    headers = [
      {"Authorization", "Bearer owner"},
      {"Content-Type", "application/json"}
    ]
    
    request = Finch.build(:get, url, headers)
    
    case Finch.request(request, Shared.Finch) do
      {:ok, %{status: 200, body: response_body}} ->
        {:ok, Jason.decode!(response_body)}
      {:ok, %{status: status, body: response_body}} ->
        Logger.error("Firestore error: #{status} - #{response_body}")
        {:error, response_body}
      {:error, reason} ->
        Logger.error("HTTP error: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @doc """
  ドキュメントを削除
  """
  def delete_document(client, project_id, collection, document_id) do
    url = "#{client.base_url}/projects/#{project_id}/databases/(default)/documents/#{collection}/#{document_id}"
    
    headers = [
      {"Authorization", "Bearer owner"},
      {"Content-Type", "application/json"}
    ]
    
    request = Finch.build(:delete, url, headers)
    
    case Finch.request(request, Shared.Finch) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok
      {:ok, %{status: status, body: response_body}} ->
        Logger.error("Firestore error: #{status} - #{response_body}")
        {:error, response_body}
      {:error, reason} ->
        Logger.error("HTTP error: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @doc """
  バッチ書き込み
  """
  def commit_writes(client, project_id, writes) do
    url = "#{client.base_url}/projects/#{project_id}/databases/(default)/documents:commit"
    
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
    
    headers = [
      {"Authorization", "Bearer owner"},
      {"Content-Type", "application/json"}
    ]
    
    request = Finch.build(:post, url, headers, Jason.encode!(body))
    
    case Finch.request(request, Shared.Finch) do
      {:ok, %{status: status, body: response_body}} when status in 200..299 ->
        {:ok, Jason.decode!(response_body)}
      {:ok, %{status: status, body: response_body}} ->
        Logger.error("Firestore error: #{status} - #{response_body}")
        {:error, response_body}
      {:error, reason} ->
        Logger.error("HTTP error: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  # Elixir の値を Firestore のフィールド形式に変換
  defp convert_to_firestore_fields(map) when is_map(map) do
    # すでに Firestore 形式の場合はそのまま返す
    if is_firestore_format?(map) do
      map
    else
      Map.new(map, fn {key, value} ->
        {to_string(key), convert_to_firestore_value(value)}
      end)
    end
  end
  
  defp convert_to_firestore_value(value) when is_map(value) do
    # すでに Firestore 形式の場合はそのまま返す
    if is_firestore_value?(value) do
      value
    else
      %{mapValue: %{fields: convert_to_firestore_fields(value)}}
    end
  end
  
  defp convert_to_firestore_value(value) do
    cond do
      is_binary(value) -> %{stringValue: value}
      is_integer(value) -> %{integerValue: to_string(value)}
      is_float(value) -> %{doubleValue: value}
      is_boolean(value) -> %{booleanValue: value}
      is_nil(value) -> %{nullValue: "NULL_VALUE"}
      is_list(value) -> %{arrayValue: %{values: Enum.map(value, &convert_to_firestore_value/1)}}
      true -> %{stringValue: to_string(value)}
    end
  end
  
  defp is_firestore_format?(map) do
    Enum.all?(map, fn {_key, value} -> is_firestore_value?(value) end)
  end
  
  defp is_firestore_value?(value) when is_map(value) do
    Map.keys(value) -- ["stringValue", "integerValue", "doubleValue", "booleanValue", 
                        "nullValue", "mapValue", "arrayValue", "timestampValue", 
                        "geoPointValue", "referenceValue", "bytesValue"] == []
  end
  defp is_firestore_value?(_), do: false
end
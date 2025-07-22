defmodule Shared.Infrastructure.Firestore.BatchOperations do
  @moduledoc """
  Firestore バッチ操作の実装
  
  大量のドキュメントの削除や更新を効率的に行います。
  """

  alias Shared.Infrastructure.Firestore.{Client, Repository}
  alias GoogleApi.Firestore.V1.Api.Projects
  require Logger

  @batch_size 500  # Firestore の制限

  @doc """
  コレクション内の全ドキュメントを削除する
  """
  def delete_all(collection) do
    with {:ok, conn} <- Client.get_connection(),
         project_id <- Client.get_project_id(:shared) do
      delete_collection_batch(conn, project_id, collection, 0)
    end
  end

  @doc """
  条件に一致するドキュメントを削除する
  """
  def delete_where(collection, filters) do
    with {:ok, documents} <- Repository.query(collection, filters),
         {:ok, conn} <- Client.get_connection(),
         project_id <- Client.get_project_id(:shared) do
      
      doc_ids = Enum.map(documents, fn doc -> 
        Map.get(doc, "id") || Map.get(doc, :id)
      end)
      
      delete_documents_batch(conn, project_id, collection, doc_ids)
    end
  end

  @doc """
  複数のドキュメントをバッチで保存する
  """
  def save_all(collection, documents) do
    with {:ok, conn} <- Client.get_connection(),
         project_id <- Client.get_project_id(:shared) do
      
      documents
      |> Enum.chunk_every(@batch_size)
      |> Enum.reduce({:ok, 0}, fn batch, {:ok, count} ->
        case save_batch(conn, project_id, collection, batch) do
          {:ok, batch_count} -> {:ok, count + batch_count}
          error -> error
        end
      end)
    end
  end

  # Private functions

  defp delete_collection_batch(conn, project_id, collection, deleted_count) do
    parent = "projects/#{project_id}/databases/(default)/documents"
    
    # ドキュメントのリストを取得
    case Projects.firestore_projects_databases_documents_list(
      conn,
      parent,
      collection,
      pageSize: @batch_size
    ) do
      {:ok, %{documents: nil}} ->
        {:ok, deleted_count}
      
      {:ok, %{documents: []}} ->
        {:ok, deleted_count}
      
      {:ok, %{documents: documents}} ->
        # バッチで削除
        delete_count = length(documents)
        
        Enum.each(documents, fn doc ->
          Projects.firestore_projects_databases_documents_delete(conn, doc.name)
        end)
        
        Logger.info("Deleted #{delete_count} documents from #{collection}")
        
        # 次のバッチを処理
        delete_collection_batch(conn, project_id, collection, deleted_count + delete_count)
      
      error ->
        Logger.error("Failed to list documents for deletion: #{inspect(error)}")
        error
    end
  end

  defp delete_documents_batch(conn, project_id, collection, doc_ids) do
    doc_ids
    |> Enum.chunk_every(@batch_size)
    |> Enum.reduce({:ok, 0}, fn batch, {:ok, count} ->
      Enum.each(batch, fn doc_id ->
        name = "projects/#{project_id}/databases/(default)/documents/#{collection}/#{doc_id}"
        Projects.firestore_projects_databases_documents_delete(conn, name)
      end)
      
      {:ok, count + length(batch)}
    end)
  end

  defp save_batch(conn, project_id, collection, documents) do
    parent = "projects/#{project_id}/databases/(default)/documents"
    
    results = Enum.map(documents, fn {id, data} ->
      document = build_document(data)
      
      Projects.firestore_projects_databases_documents_create_document(
        conn,
        parent,
        collection,
        documentId: id,
        body: document
      )
    end)
    
    success_count = Enum.count(results, fn 
      {:ok, _} -> true
      _ -> false
    end)
    
    {:ok, success_count}
  end

  defp build_document(data) do
    %GoogleApi.Firestore.V1.Model.Document{
      fields: encode_fields(data)
    }
  end

  defp encode_fields(data) when is_map(data) do
    Map.new(data, fn {key, value} -> 
      {to_string(key), encode_value(value)}
    end)
  end

  defp encode_value(value) when is_binary(value) do
    %GoogleApi.Firestore.V1.Model.Value{stringValue: value}
  end

  defp encode_value(value) when is_integer(value) do
    %GoogleApi.Firestore.V1.Model.Value{integerValue: to_string(value)}
  end

  defp encode_value(value) when is_float(value) do
    %GoogleApi.Firestore.V1.Model.Value{doubleValue: value}
  end

  defp encode_value(value) when is_boolean(value) do
    %GoogleApi.Firestore.V1.Model.Value{booleanValue: value}
  end

  defp encode_value(nil) do
    %GoogleApi.Firestore.V1.Model.Value{nullValue: "NULL_VALUE"}
  end

  defp encode_value(value) when is_map(value) do
    %GoogleApi.Firestore.V1.Model.Value{
      mapValue: %GoogleApi.Firestore.V1.Model.MapValue{
        fields: encode_fields(value)
      }
    }
  end

  defp encode_value(value) when is_list(value) do
    %GoogleApi.Firestore.V1.Model.Value{
      arrayValue: %GoogleApi.Firestore.V1.Model.ArrayValue{
        values: Enum.map(value, &encode_value/1)
      }
    }
  end

  defp encode_value(%DateTime{} = value) do
    %GoogleApi.Firestore.V1.Model.Value{
      timestampValue: DateTime.to_iso8601(value)
    }
  end

  defp encode_value(value) do
    %GoogleApi.Firestore.V1.Model.Value{stringValue: to_string(value)}
  end
end
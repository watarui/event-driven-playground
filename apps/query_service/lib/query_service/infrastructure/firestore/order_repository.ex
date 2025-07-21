defmodule QueryService.Infrastructure.Firestore.OrderRepository do
  @moduledoc """
  注文リポジトリの Firestore 実装

  注文の Read Model を Firestore で管理します
  """

  alias Shared.Infrastructure.Firestore.Client
  alias GoogleApi.Firestore.V1.Api.Projects
  alias GoogleApi.Firestore.V1.Model.{Document, Value, RunQueryRequest, StructuredQuery}

  # コレクション名
  @collection "order_projections"

  @doc """
  注文を作成する
  """
  def create(attrs) do
    with {:ok, conn} <- Client.get_connection(:query),
         project_id <- Client.get_project_id(:query),
         document <- build_order_document(attrs),
         {:ok, _result} <- create_document(conn, project_id, attrs.id, document) do
      {:ok, attrs}
    end
  end

  @doc """
  注文を更新する
  """
  def update(id, attrs) do
    with {:ok, conn} <- Client.get_connection(:query),
         project_id <- Client.get_project_id(:query),
         document <- build_order_document(attrs),
         {:ok, _result} <- update_document(conn, project_id, id, document) do
      {:ok, Map.put(attrs, :id, id)}
    end
  end

  @doc """
  注文を取得する
  """
  def get(id) do
    with {:ok, conn} <- Client.get_connection(:query),
         project_id <- Client.get_project_id(:query),
         {:ok, document} <- get_document(conn, project_id, id) do
      {:ok, parse_order_document(document)}
    else
      {:error, 404} -> {:error, :not_found}
      error -> error
    end
  end

  @doc """
  すべての注文を取得する
  """
  def get_all(filters \\ %{}) do
    with {:ok, conn} <- Client.get_connection(:query),
         project_id <- Client.get_project_id(:query),
         query <- build_query(filters),
         {:ok, documents} <- run_query(conn, project_id, query) do
      orders = Enum.map(documents, &parse_order_document/1)
      {:ok, orders}
    end
  end

  @doc """
  ユーザーの注文を取得する
  """
  def get_by_user(user_id, filters \\ %{}) do
    filters = Map.put(filters, :user_id, user_id)
    get_all(filters)
  end

  @doc """
  注文を検索する
  """
  def search(filters \\ %{}) do
    get_all(filters)
  end

  @doc """
  注文を削除する
  """
  def delete(id) do
    with {:ok, conn} <- Client.get_connection(:query),
         project_id <- Client.get_project_id(:query),
         {:ok, _} <- delete_document(conn, project_id, id) do
      :ok
    end
  end

  @doc """
  すべての注文を削除する
  """
  def delete_all do
    with {:ok, conn} <- Client.get_connection(:query),
         project_id <- Client.get_project_id(:query),
         {:ok, documents} <- list_all_documents(conn, project_id) do
      count = length(documents)
      
      # バッチ削除
      Enum.each(documents, fn doc ->
        doc_id = extract_document_id(doc.name)
        delete_document(conn, project_id, doc_id)
      end)
      
      {:ok, count}
    end
  end

  # Private functions

  defp create_document(conn, project_id, id, document) do
    parent = "projects/#{project_id}/databases/(default)/documents"
    
    Projects.firestore_projects_databases_documents_create_document(
      conn,
      parent,
      @collection,
      body: document,
      documentId: id
    )
  end

  defp update_document(conn, project_id, id, document) do
    name = "projects/#{project_id}/databases/(default)/documents/#{@collection}/#{id}"
    
    Projects.firestore_projects_databases_documents_patch(
      conn,
      name,
      body: document,
      updateMask_fieldPaths: ["*"]
    )
  end

  defp get_document(conn, project_id, id) do
    name = "projects/#{project_id}/databases/(default)/documents/#{@collection}/#{id}"
    Projects.firestore_projects_databases_documents_get(conn, name)
  end

  defp delete_document(conn, project_id, id) do
    name = "projects/#{project_id}/databases/(default)/documents/#{@collection}/#{id}"
    Projects.firestore_projects_databases_documents_delete(conn, name)
  end

  defp list_all_documents(conn, project_id) do
    parent = "projects/#{project_id}/databases/(default)/documents"
    
    case Projects.firestore_projects_databases_documents_list(
      conn,
      parent,
      @collection,
      pageSize: 1000
    ) do
      {:ok, response} -> {:ok, response.documents || []}
      error -> error
    end
  end

  defp run_query(conn, project_id, query) do
    parent = "projects/#{project_id}/databases/(default)/documents"
    
    request = %RunQueryRequest{
      structuredQuery: query
    }
    
    case Projects.firestore_projects_databases_documents_run_query(
      conn,
      parent,
      body: request
    ) do
      {:ok, results} ->
        documents = Enum.map(results, fn result -> result.document end)
        {:ok, documents}
      error ->
        error
    end
  end

  defp build_query(filters) do
    query = %StructuredQuery{
      from: [%{collectionId: @collection}]
    }

    # フィルタを追加
    query =
      filters
      |> Enum.reduce(query, fn
        {:user_id, user_id}, q -> 
          add_filter(q, "user_id", "EQUAL", user_id)
        {:status, status}, q -> 
          add_filter(q, "status", "EQUAL", status)
        {:limit, limit}, q -> 
          %{q | limit: %{value: limit}}
        _, q -> 
          q
      end)
    
    # ソート順を追加
    case Map.get(filters, :sort_by) do
      nil -> query
      field -> add_order_by(query, field, Map.get(filters, :sort_order, :asc))
    end
  end

  defp add_filter(query, field, op, value) do
    filter = %{
      fieldFilter: %{
        field: %{fieldPath: field},
        op: op,
        value: build_value(value)
      }
    }
    
    where = Map.get(query, :where, %{})
    updated_where = 
      case where do
        %{compositeFilter: %{filters: filters}} ->
          %{compositeFilter: %{op: "AND", filters: filters ++ [filter]}}
        _ ->
          filter
      end
    
    %{query | where: updated_where}
  end

  defp add_order_by(query, field, direction) do
    order = %{
      field: %{fieldPath: field},
      direction: if(direction == :desc, do: "DESCENDING", else: "ASCENDING")
    }
    
    %{query | orderBy: [order]}
  end

  defp build_order_document(attrs) do
    fields = 
      attrs
      |> Map.to_list()
      |> Enum.map(fn {key, value} -> {to_string(key), build_value(value)} end)
      |> Enum.into(%{})
    
    %Document{fields: fields}
  end

  defp build_value(value) do
    case value do
      v when is_binary(v) -> %Value{stringValue: v}
      v when is_integer(v) -> %Value{integerValue: to_string(v)}
      v when is_float(v) -> %Value{doubleValue: v}
      v when is_boolean(v) -> %Value{booleanValue: v}
      %Decimal{} = v -> %Value{stringValue: Decimal.to_string(v)}
      %DateTime{} = v -> %Value{timestampValue: DateTime.to_iso8601(v)}
      v when is_map(v) -> %Value{mapValue: %{fields: build_map_fields(v)}}
      v when is_list(v) -> %Value{arrayValue: %{values: Enum.map(v, &build_value/1)}}
      nil -> %Value{nullValue: "NULL_VALUE"}
      v -> %Value{stringValue: to_string(v)}
    end
  end

  defp build_map_fields(map) do
    map
    |> Map.to_list()
    |> Enum.map(fn {k, v} -> {to_string(k), build_value(v)} end)
    |> Enum.into(%{})
  end

  defp parse_order_document(%Document{fields: fields}) do
    fields
    |> Enum.map(fn {key, value} -> {String.to_atom(key), parse_value(value)} end)
    |> Enum.into(%{})
  end

  defp parse_value(%Value{} = value) do
    cond do
      value.stringValue != nil -> value.stringValue
      value.integerValue != nil -> String.to_integer(value.integerValue)
      value.doubleValue != nil -> value.doubleValue
      value.booleanValue != nil -> value.booleanValue
      value.timestampValue != nil -> parse_timestamp(value.timestampValue)
      value.mapValue != nil -> parse_map_value(value.mapValue)
      value.arrayValue != nil -> Enum.map(value.arrayValue.values || [], &parse_value/1)
      value.nullValue != nil -> nil
      true -> nil
    end
  end

  defp parse_map_value(%{fields: fields}) do
    fields
    |> Enum.map(fn {k, v} -> {String.to_atom(k), parse_value(v)} end)
    |> Enum.into(%{})
  end

  defp parse_timestamp(iso8601_string) do
    {:ok, datetime, _} = DateTime.from_iso8601(iso8601_string)
    datetime
  end

  defp extract_document_id(document_name) do
    document_name
    |> String.split("/")
    |> List.last()
  end
end
defmodule QueryService.Infrastructure.Firestore.CategoryRepository do
  @moduledoc """
  カテゴリリポジトリの Firestore 実装

  カテゴリの Read Model を Firestore で管理します
  """

  alias Shared.Infrastructure.Firestore.Client
  alias GoogleApi.Firestore.V1.Api.Projects
  alias GoogleApi.Firestore.V1.Model.{Document, Value, RunQueryRequest, StructuredQuery}

  # コレクション名
  @collection "category_tree"

  @doc """
  カテゴリを作成する
  """
  def create(attrs) do
    with {:ok, conn} <- Client.get_connection(:query),
         project_id <- Client.get_project_id(:query),
         document <- build_category_document(attrs),
         {:ok, _result} <- create_document(conn, project_id, attrs.id, document) do
      {:ok, attrs}
    end
  end

  @doc """
  カテゴリを更新する
  """
  def update(id, attrs) do
    with {:ok, conn} <- Client.get_connection(:query),
         project_id <- Client.get_project_id(:query),
         document <- build_category_document(attrs),
         {:ok, _result} <- update_document(conn, project_id, id, document) do
      {:ok, Map.put(attrs, :id, id)}
    end
  end

  @doc """
  カテゴリを取得する
  """
  def get(id) do
    with {:ok, conn} <- Client.get_connection(:query),
         project_id <- Client.get_project_id(:query),
         {:ok, document} <- get_document(conn, project_id, id) do
      {:ok, parse_category_document(document)}
    else
      {:error, 404} -> {:error, :not_found}
      error -> error
    end
  end

  @doc """
  すべてのカテゴリを取得する
  """
  def get_all do
    with {:ok, conn} <- Client.get_connection(:query),
         project_id <- Client.get_project_id(:query),
         {:ok, documents} <- list_all_documents(conn, project_id) do
      categories = Enum.map(documents, &parse_category_document/1)
      {:ok, categories}
    end
  end

  @doc """
  ルートカテゴリを取得する
  """
  def get_root_categories do
    with {:ok, conn} <- Client.get_connection(:query),
         project_id <- Client.get_project_id(:query),
         query <- build_root_query(),
         {:ok, documents} <- run_query(conn, project_id, query) do
      categories = Enum.map(documents, &parse_category_document/1)
      {:ok, categories}
    end
  end

  @doc """
  子カテゴリを取得する
  """
  def get_children(parent_id) do
    with {:ok, conn} <- Client.get_connection(:query),
         project_id <- Client.get_project_id(:query),
         query <- build_children_query(parent_id),
         {:ok, documents} <- run_query(conn, project_id, query) do
      categories = Enum.map(documents, &parse_category_document/1)
      {:ok, categories}
    end
  end

  @doc """
  カテゴリツリーを取得する
  """
  def get_tree do
    with {:ok, all_categories} <- get_all() do
      # 親子関係を構築
      tree = build_tree(all_categories)
      {:ok, tree}
    end
  end

  @doc """
  カテゴリを削除する
  """
  def delete(id) do
    with {:ok, conn} <- Client.get_connection(:query),
         project_id <- Client.get_project_id(:query),
         {:ok, _} <- delete_document(conn, project_id, id) do
      :ok
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

  defp build_root_query do
    %StructuredQuery{
      from: [%{collectionId: @collection}],
      where: %{
        fieldFilter: %{
          field: %{fieldPath: "parent_id"},
          op: "IS_NULL"
        }
      },
      orderBy: [%{
        field: %{fieldPath: "position"},
        direction: "ASCENDING"
      }]
    }
  end

  defp build_children_query(parent_id) do
    %StructuredQuery{
      from: [%{collectionId: @collection}],
      where: %{
        fieldFilter: %{
          field: %{fieldPath: "parent_id"},
          op: "EQUAL",
          value: %Value{stringValue: parent_id}
        }
      },
      orderBy: [%{
        field: %{fieldPath: "position"},
        direction: "ASCENDING"
      }]
    }
  end

  defp build_category_document(attrs) do
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

  defp parse_category_document(%Document{fields: fields, name: name}) do
    # ドキュメント名から ID を抽出
    id = extract_document_id(name)
    
    parsed =
      fields
      |> Enum.map(fn {key, value} -> {String.to_atom(key), parse_value(value)} end)
      |> Enum.into(%{})
    
    Map.put(parsed, :id, id)
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

  defp build_tree(categories) do
    # カテゴリを ID でグループ化
    _by_id = Enum.into(categories, %{}, fn cat -> {cat.id, cat} end)
    
    # 親子関係を構築
    categories
    |> Enum.map(fn category ->
      children = 
        categories
        |> Enum.filter(fn c -> c[:parent_id] == category.id end)
        |> Enum.sort_by(fn c -> c[:position] || 0 end)
      
      Map.put(category, :children, children)
    end)
    |> Enum.filter(fn c -> is_nil(c[:parent_id]) end)
    |> Enum.sort_by(fn c -> c[:position] || 0 end)
  end
end
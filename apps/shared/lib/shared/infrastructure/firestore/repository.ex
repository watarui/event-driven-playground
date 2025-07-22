defmodule Shared.Infrastructure.Firestore.Repository do
  @moduledoc """
  Firestore を使用したリポジトリの基本実装
  """

  @behaviour Shared.Infrastructure.Repository

  alias Shared.Infrastructure.Firestore.Client
  alias GoogleApi.Firestore.V1.Api.Projects
  alias GoogleApi.Firestore.V1.Model.{Document, Value}

  require Logger

  @impl true
  def save(collection, id, entity) do
    with {:ok, conn} <- Client.get_connection(),
         project_id <- Client.get_project_id(:shared),
         document <- build_document(entity),
         {:ok, _result} <- create_or_update_document(conn, project_id, collection, id, document) do
      {:ok, entity}
    end
  end

  @impl true
  def get(collection, id) do
    with {:ok, conn} <- Client.get_connection(),
         project_id <- Client.get_project_id(:shared),
         {:ok, document} <- get_document(conn, project_id, collection, id) do
      {:ok, parse_document(document)}
    else
      {:error, 404} -> {:error, :not_found}
      error -> error
    end
  end

  @impl true
  def list(collection, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)

    with {:ok, conn} <- Client.get_connection(),
         project_id <- Client.get_project_id(:shared),
         {:ok, response} <- list_documents(conn, project_id, collection, limit) do
      documents = response.documents || []
      {:ok, Enum.map(documents, &parse_document/1)}
    end
  end

  @impl true
  def delete(collection, id) do
    with {:ok, conn} <- Client.get_connection(),
         project_id <- Client.get_project_id(:shared),
         {:ok, _} <- delete_document(conn, project_id, collection, id) do
      :ok
    end
  end

  @impl true
  def transaction(fun) do
    alias Shared.Infrastructure.Firestore.Transaction
    
    Transaction.run(fn tx ->
      # トランザクションコンテキストを Process に保存
      Process.put(:firestore_transaction, tx)
      
      try do
        result = fun.()
        Process.delete(:firestore_transaction)
        result
      rescue
        e ->
          Process.delete(:firestore_transaction)
          reraise e, __STACKTRACE__
      end
    end)
  end

  @impl true
  def query(collection, filters, opts \\ []) do
    with {:ok, conn} <- Client.get_connection(),
         project_id <- Client.get_project_id(:shared) do
      
      query = build_query(collection, filters, opts)
      parent = "projects/#{project_id}/databases/(default)/documents"
      
      case Projects.firestore_projects_databases_documents_run_query(
        conn,
        parent,
        body: query
      ) do
        {:ok, responses} ->
          documents = extract_documents_from_responses(responses)
          {:ok, Enum.map(documents, &parse_document/1)}
        error ->
          Logger.error("Query failed: #{inspect(error)}")
          error
      end
    end
  end

  defp build_query(collection, filters, opts) do
    base_query = %{
      structuredQuery: %{
        from: [%{collectionId: collection}]
      }
    }

    base_query
    |> add_filters(filters)
    |> add_ordering(opts)
    |> add_limit(opts)
  end

  defp add_filters(query, filters) when map_size(filters) == 0, do: query
  defp add_filters(query, filters) do
    filter_conditions = Enum.map(filters, fn {field, value} ->
      %{
        fieldFilter: %{
          field: %{fieldPath: to_string(field)},
          op: "EQUAL",
          value: build_value(value)
        }
      }
    end)

    where_clause = case filter_conditions do
      [single] -> single
      multiple -> %{
        compositeFilter: %{
          op: "AND",
          filters: multiple
        }
      }
    end

    put_in(query[:structuredQuery][:where], where_clause)
  end

  defp add_ordering(query, opts) do
    case Keyword.get(opts, :order_by) do
      nil -> query
      {field, direction} ->
        order = %{
          field: %{fieldPath: to_string(field)},
          direction: to_string(direction) |> String.upcase()
        }
        put_in(query[:structuredQuery][:orderBy], [order])
    end
  end

  defp add_limit(query, opts) do
    case Keyword.get(opts, :limit) do
      nil -> query
      limit -> put_in(query[:structuredQuery][:limit], limit)
    end
  end

  defp extract_documents_from_responses(responses) do
    Enum.flat_map(responses, fn response ->
      case response do
        %{document: doc} when not is_nil(doc) -> [doc]
        _ -> []
      end
    end)
  end

  # Private functions

  defp create_or_update_document(conn, project_id, collection, id, document) do
    parent = "projects/#{project_id}/databases/(default)/documents"
    name = "#{parent}/#{collection}/#{id}"

    Projects.firestore_projects_databases_documents_patch(
      conn,
      name,
      body: document,
      updateMask_fieldPaths: ["*"]
    )
  end

  defp get_document(conn, project_id, collection, id) do
    name = "projects/#{project_id}/databases/(default)/documents/#{collection}/#{id}"
    Projects.firestore_projects_databases_documents_get(conn, name)
  end

  defp list_documents(conn, project_id, collection, limit) do
    parent = "projects/#{project_id}/databases/(default)/documents"

    Projects.firestore_projects_databases_documents_list(
      conn,
      parent,
      collection,
      pageSize: limit
    )
  end

  defp delete_document(conn, project_id, collection, id) do
    name = "projects/#{project_id}/databases/(default)/documents/#{collection}/#{id}"
    Projects.firestore_projects_databases_documents_delete(conn, name)
  end

  defp build_document(entity) when is_map(entity) do
    fields =
      entity
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

  defp parse_document(%Document{fields: fields}) do
    fields
    |> Enum.map(fn {key, value} -> {key, parse_value(value)} end)
    |> Enum.into(%{})
  end

  defp parse_value(%Value{} = value) do
    cond do
      value.stringValue != nil -> value.stringValue
      value.integerValue != nil -> String.to_integer(value.integerValue)
      value.doubleValue != nil -> value.doubleValue
      value.booleanValue != nil -> value.booleanValue
      value.mapValue != nil -> parse_map_value(value.mapValue)
      value.arrayValue != nil -> Enum.map(value.arrayValue.values || [], &parse_value/1)
      value.nullValue != nil -> nil
      true -> nil
    end
  end

  defp parse_map_value(%{fields: fields}) do
    fields
    |> Enum.map(fn {k, v} -> {k, parse_value(v)} end)
    |> Enum.into(%{})
  end
end

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
    # Firestore トランザクションの実装
    # TODO: 実装が複雑なため、後で詳細実装
    Logger.warning("Firestore transaction not fully implemented yet")
    fun.()
  end

  @impl true
  def query(_collection, _filters, _opts \\ []) do
    # TODO: Firestore クエリの実装
    Logger.warning("Firestore query not fully implemented yet")
    {:ok, []}
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

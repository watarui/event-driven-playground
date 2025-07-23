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

    with {:ok, conn} <- Client.get_connection() do
      project_id = Client.get_project_id(:shared)

      # エミュレータを使用している場合
      if Client.using_emulator?(:shared) do
        case list_documents_emulator(conn, project_id, collection, limit) do
          {:ok, documents} -> {:ok, documents}
          error -> error
        end
      else
        # 本番環境
        case list_documents(conn, project_id, collection, limit) do
          {:ok, response} ->
            documents = response.documents || []
            {:ok, Enum.map(documents, &parse_document/1)}

          error ->
            error
        end
      end
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
    filter_conditions =
      Enum.map(filters, fn {field, value} ->
        %{
          fieldFilter: %{
            field: %{fieldPath: to_string(field)},
            op: "EQUAL",
            value: build_value(value)
          }
        }
      end)

    where_clause =
      case filter_conditions do
        [single] ->
          single

        multiple ->
          %{
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
      nil ->
        query

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
    # 構造体の場合は Map.from_struct で変換し、__struct__ フィールドを除外
    clean_entity =
      if is_struct(entity) do
        Map.from_struct(entity)
      else
        entity
      end

    fields =
      clean_entity
      # 念のため明示的に削除
      |> Map.delete(:__struct__)
      |> Map.to_list()
      |> Enum.map(fn {key, value} -> {to_string(key), build_value(value)} end)
      |> Enum.into(%{})

    %Document{fields: fields}
  end

  defp build_value(value) do
    case value do
      v when is_binary(v) ->
        %Value{stringValue: v}

      v when is_integer(v) ->
        %Value{integerValue: to_string(v)}

      v when is_float(v) ->
        %Value{doubleValue: v}

      v when is_boolean(v) ->
        %Value{booleanValue: v}

      v when is_map(v) ->
        %Value{mapValue: %{fields: build_map_fields(v)}}

      v when is_list(v) ->
        %Value{arrayValue: %{values: Enum.map(v, &build_value/1)}}

      nil ->
        %Value{nullValue: "NULL_VALUE"}

      # Handle DateTime and timestamp tuples
      %DateTime{} = dt ->
        %Value{timestampValue: DateTime.to_iso8601(dt)}

      # Handle Erlang timestamp tuples
      {mega, sec, _micro} when is_integer(mega) and is_integer(sec) ->
        dt = DateTime.from_unix!(mega * 1_000_000 + sec)
        %Value{timestampValue: DateTime.to_iso8601(dt)}

      v when is_tuple(v) ->
        # Convert other tuples to string representation
        %Value{stringValue: inspect(v)}

      v ->
        %Value{stringValue: to_string(v)}
    end
  end

  defp build_map_fields(map) do
    # ネストされたマップでも __struct__ フィールドを除外
    clean_map =
      if is_struct(map) do
        Map.from_struct(map)
      else
        map
      end

    clean_map
    # 念のため明示的に削除
    |> Map.delete(:__struct__)
    |> Map.to_list()
    |> Enum.map(fn {k, v} -> {to_string(k), build_value(v)} end)
    |> Enum.into(%{})
  end

  # エミュレータ用のリスト取得関数
  defp list_documents_emulator(conn, project_id, collection, limit) do
    url = "/projects/#{project_id}/databases/(default)/documents/#{collection}"

    case Tesla.get(conn, url, query: [pageSize: limit]) do
      {:ok, %{status: 200, body: body}} ->
        documents = body["documents"] || []
        parsed_documents = Enum.map(documents, &parse_emulator_document/1)
        {:ok, parsed_documents}

      {:ok, %{status: status, body: body}} ->
        {:error, "Failed to list documents: #{status} - #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # エミュレータのドキュメントをパース
  defp parse_emulator_document(doc) do
    fields = doc["fields"] || %{}

    fields
    |> Enum.map(fn {key, value} -> {key, parse_emulator_value(value)} end)
    |> Enum.into(%{})
  end

  # エミュレータの値をパース
  defp parse_emulator_value(value) when is_map(value) do
    cond do
      Map.has_key?(value, "stringValue") ->
        value["stringValue"]

      Map.has_key?(value, "integerValue") ->
        String.to_integer(value["integerValue"])

      Map.has_key?(value, "doubleValue") ->
        value["doubleValue"]

      Map.has_key?(value, "booleanValue") ->
        value["booleanValue"]

      Map.has_key?(value, "nullValue") ->
        nil

      Map.has_key?(value, "timestampValue") ->
        value["timestampValue"]

      Map.has_key?(value, "mapValue") ->
        fields = value["mapValue"]["fields"] || %{}
        Enum.map(fields, fn {k, v} -> {k, parse_emulator_value(v)} end) |> Enum.into(%{})

      Map.has_key?(value, "arrayValue") ->
        values = value["arrayValue"]["values"] || []
        Enum.map(values, &parse_emulator_value/1)

      true ->
        value
    end
  end

  defp parse_emulator_value(value), do: value

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

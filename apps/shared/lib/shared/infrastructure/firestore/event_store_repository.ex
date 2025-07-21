defmodule Shared.Infrastructure.Firestore.EventStoreRepository do
  @moduledoc """
  Firestore を使用したイベントストアリポジトリの実装

  イベントは以下の構造で保存されます：
  event_store/
    {aggregate_type}/
      {aggregate_id}/
        events/ (subcollection)
          {event_id} - タイムスタンプベースのID
        snapshots/ (subcollection)
          {version} - バージョン番号
  """

  @behaviour Shared.Infrastructure.EventStoreRepository

  alias Shared.Infrastructure.Firestore.Client
  alias GoogleApi.Firestore.V1.Api.Projects
  alias GoogleApi.Firestore.V1.Model.{Document, Value, Write}

  require Logger

  @events_collection "events"
  @snapshots_collection "snapshots"

  @impl true
  def append_events(aggregate_id, events) do
    with {:ok, conn} <- Client.get_connection(:event_store),
         project_id <- Client.get_project_id(:event_store),
         writes <- build_event_writes(project_id, aggregate_id, events),
         {:ok, _response} <- commit_writes(conn, project_id, writes) do
      # 最新バージョンを返す
      version = length(events)
      {:ok, version}
    end
  end

  @impl true
  def get_events(aggregate_id, opts \\ []) do
    from_version = Keyword.get(opts, :from_version, 0)

    with {:ok, conn} <- Client.get_connection(:event_store),
         project_id <- Client.get_project_id(:event_store),
         {:ok, documents} <- query_events(conn, project_id, aggregate_id, from_version) do
      events = Enum.map(documents, &parse_event_document/1)
      {:ok, events}
    end
  end

  @impl true
  def get_events_after_version(aggregate_id, version) do
    get_events(aggregate_id, from_version: version)
  end

  @impl true
  def stream_all_events(_opts \\ []) do
    # TODO: 全イベントのストリーミング実装
    # バッチサイズやページネーションを考慮
    Logger.warning("stream_all_events not implemented yet")
    []
  end

  @impl true
  def save_snapshot(aggregate_id, snapshot, version) do
    with {:ok, conn} <- Client.get_connection(:event_store),
         project_id <- Client.get_project_id(:event_store),
         document <- build_snapshot_document(snapshot, version),
         {:ok, _} <- save_snapshot_document(conn, project_id, aggregate_id, version, document) do
      :ok
    end
  end

  @impl true
  def get_latest_snapshot(aggregate_id) do
    with {:ok, conn} <- Client.get_connection(:event_store),
         project_id <- Client.get_project_id(:event_store),
         {:ok, document} <- get_latest_snapshot_document(conn, project_id, aggregate_id) do
      snapshot = parse_snapshot_document(document)
      {:ok, snapshot}
    else
      {:error, :not_found} -> {:error, :not_found}
      error -> error
    end
  end

  # Private functions

  defp build_event_writes(project_id, aggregate_id, events) do
    {aggregate_type, aggregate_uuid} = parse_aggregate_id(aggregate_id)

    base_path =
      "projects/#{project_id}/databases/(default)/documents/event_store/#{aggregate_type}/#{aggregate_uuid}/#{@events_collection}"

    Enum.map(events, fn event ->
      event_id = generate_event_id(event)
      document_path = "#{base_path}/#{event_id}"

      %Write{
        update: %Document{
          name: document_path,
          fields: %{
            "aggregate_id" => %Value{stringValue: aggregate_id},
            "event_type" => %Value{stringValue: to_string(event.event_type)},
            "event_data" => %Value{stringValue: Jason.encode!(event.event_data)},
            "metadata" => %Value{stringValue: Jason.encode!(event.metadata)},
            "occurred_at" => %Value{timestampValue: DateTime.to_iso8601(event.occurred_at)},
            "version" => %Value{integerValue: to_string(event.version)}
          }
        }
      }
    end)
  end

  defp commit_writes(conn, project_id, writes) do
    if emulator_client?(conn) do
      # エミュレータクライアントの場合
      Shared.Infrastructure.Firestore.EmulatorClient.commit_writes(conn, project_id, writes)
    else
      # Google API クライアントの場合
      database = "projects/#{project_id}/databases/(default)"

      # CommitRequest を Map として作成
      request = %{
        writes: writes
      }

      Projects.firestore_projects_databases_documents_commit(conn, database, body: request)
    end
  end

  defp query_events(conn, project_id, aggregate_id, from_version) do
    {aggregate_type, aggregate_uuid} = parse_aggregate_id(aggregate_id)

    if emulator_client?(conn) do
      # エミュレータクライアントの場合
      collection_path = "event_store/#{aggregate_type}/#{aggregate_uuid}/#{@events_collection}"

      case Shared.Infrastructure.Firestore.EmulatorClient.list_documents(
             conn,
             project_id,
             collection_path,
             orderBy: "version",
             pageSize: 1000
           ) do
        {:ok, result} ->
          documents = Map.get(result, "documents", [])

          filtered =
            Enum.filter(documents, fn doc ->
              version = get_in(doc, ["fields", "version", "integerValue"])
              version && String.to_integer(version) > from_version
            end)

          {:ok, filtered}

        error ->
          error
      end
    else
      # Google API クライアントの場合
      parent =
        "projects/#{project_id}/databases/(default)/documents/event_store/#{aggregate_type}/#{aggregate_uuid}"

      Projects.firestore_projects_databases_documents_list(
        conn,
        parent,
        @events_collection,
        orderBy: "version",
        pageSize: 1000
      )
      |> case do
        {:ok, response} ->
          documents = response.documents || []

          filtered =
            Enum.filter(documents, fn doc ->
              version = get_in(doc.fields, ["version", "integerValue"])
              version && String.to_integer(version) > from_version
            end)

          {:ok, filtered}

        error ->
          error
      end
    end
  end

  defp parse_event_document(document) do
    # Map形式（エミュレータ）とstruct形式（Google API）の両方に対応
    fields =
      if is_map(document) && Map.has_key?(document, "fields") do
        document["fields"]
      else
        document.fields
      end

    %{
      aggregate_id: get_string_value(fields, "aggregate_id"),
      event_type: String.to_atom(get_string_value(fields, "event_type")),
      event_data: Jason.decode!(get_string_value(fields, "event_data")),
      metadata: Jason.decode!(get_string_value(fields, "metadata")),
      occurred_at: parse_timestamp(get_string_value(fields, "occurred_at")),
      version: String.to_integer(get_string_value(fields, "version"))
    }
  end

  defp build_snapshot_document(snapshot, version) do
    %Document{
      fields: %{
        "snapshot_data" => %Value{stringValue: Jason.encode!(snapshot)},
        "version" => %Value{integerValue: to_string(version)},
        "created_at" => %Value{timestampValue: DateTime.to_iso8601(DateTime.utc_now())}
      }
    }
  end

  defp save_snapshot_document(conn, project_id, aggregate_id, version, document) do
    {aggregate_type, aggregate_uuid} = parse_aggregate_id(aggregate_id)

    if emulator_client?(conn) do
      # エミュレータクライアントの場合
      collection_path = "event_store/#{aggregate_type}/#{aggregate_uuid}/#{@snapshots_collection}"
      fields = document.fields

      Shared.Infrastructure.Firestore.EmulatorClient.create_or_update_document(
        conn,
        project_id,
        collection_path,
        to_string(version),
        fields
      )
    else
      # Google API クライアントの場合
      name =
        "projects/#{project_id}/databases/(default)/documents/event_store/#{aggregate_type}/#{aggregate_uuid}/#{@snapshots_collection}/#{version}"

      Projects.firestore_projects_databases_documents_patch(
        conn,
        name,
        body: document,
        updateMask_fieldPaths: ["*"]
      )
    end
  end

  defp get_latest_snapshot_document(conn, project_id, aggregate_id) do
    {aggregate_type, aggregate_uuid} = parse_aggregate_id(aggregate_id)

    if emulator_client?(conn) do
      # エミュレータクライアントの場合
      collection_path = "event_store/#{aggregate_type}/#{aggregate_uuid}/#{@snapshots_collection}"

      case Shared.Infrastructure.Firestore.EmulatorClient.list_documents(
             conn,
             project_id,
             collection_path,
             orderBy: "version desc",
             pageSize: 1
           ) do
        {:ok, result} ->
          case Map.get(result, "documents", []) do
            [document | _] -> {:ok, document}
            [] -> {:error, :not_found}
          end

        error ->
          error
      end
    else
      # Google API クライアントの場合
      parent =
        "projects/#{project_id}/databases/(default)/documents/event_store/#{aggregate_type}/#{aggregate_uuid}"

      # 最新のスナップショットを取得（version で降順ソート、1件のみ）
      Projects.firestore_projects_databases_documents_list(
        conn,
        parent,
        @snapshots_collection,
        orderBy: "version desc",
        pageSize: 1
      )
      |> case do
        {:ok, %{documents: [document | _]}} -> {:ok, document}
        {:ok, %{documents: []}} -> {:error, :not_found}
        error -> error
      end
    end
  end

  defp parse_snapshot_document(document) do
    # Map形式（エミュレータ）とstruct形式（Google API）の両方に対応
    fields =
      if is_map(document) && Map.has_key?(document, "fields") do
        document["fields"]
      else
        document.fields
      end

    snapshot_data = Jason.decode!(get_string_value(fields, "snapshot_data"))
    version = String.to_integer(get_string_value(fields, "version"))
    {snapshot_data, version}
  end

  defp parse_aggregate_id(aggregate_id) do
    # aggregate_id は "Order:uuid" の形式
    [type, uuid] = String.split(aggregate_id, ":", parts: 2)
    {type, uuid}
  end

  defp generate_event_id(event) do
    # タイムスタンプベースのID生成
    timestamp = DateTime.to_unix(event.occurred_at, :microsecond)
    "#{timestamp}_#{:crypto.strong_rand_bytes(4) |> Base.encode16()}"
  end

  defp get_string_value(fields, key) do
    # Map形式とstruct形式の両方に対応
    value =
      if is_map(fields) && !is_struct(fields) do
        # Map形式（エミュレータ）
        get_in(fields, [key, "stringValue"])
      else
        # struct形式（Google API）
        case Map.get(fields, key) do
          %{stringValue: value} -> value
          _ -> nil
        end
      end

    value || ""
  end

  defp parse_timestamp(iso8601_string) do
    {:ok, datetime, _} = DateTime.from_iso8601(iso8601_string)
    datetime
  end

  defp emulator_client?(conn) do
    # エミュレータクライアントは Map で base_url を持つ
    is_map(conn) && is_map_key(conn, :base_url)
  end
end

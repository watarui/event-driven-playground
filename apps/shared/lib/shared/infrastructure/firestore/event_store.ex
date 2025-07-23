defmodule Shared.Infrastructure.Firestore.EventStore do
  @moduledoc """
  Firestore を使用したイベントストアの実装

  イベントソーシングのためのイベント永続化と読み込みを提供します。
  """

  require Logger
  alias Shared.Infrastructure.Firestore.Client
  alias GoogleApi.Firestore.V1.Api.Projects
  alias GoogleApi.Firestore.V1.Model.{Document, Value, MapValue, ArrayValue}

  @events_collection "events"
  @snapshots_collection "snapshots"

  @doc """
  イベントを保存する
  """
  def save_events(aggregate_id, aggregate_type, events, expected_version) do
    # トランザクション内でバージョンチェックと保存を実行
    with {:ok, connection} <- Client.get_connection(),
         {:ok, _} <- verify_version(connection, aggregate_id, expected_version),
         {:ok, _} <-
           save_events_batch(connection, aggregate_id, aggregate_type, events, expected_version) do
      {:ok, events}
    else
      {:error, :version_conflict} ->
        {:error, :concurrent_modification}

      error ->
        Logger.error("Failed to save events: #{inspect(error)}")
        error
    end
  end

  @doc """
  アグリゲートのイベントを取得する
  """
  def get_events(aggregate_id, after_version \\ 0) do
    with {:ok, connection} <- Client.get_connection() do
      query_events(connection, aggregate_id, after_version)
    end
  end

  @doc """
  スナップショットを保存する
  """
  def save_snapshot(aggregate_id, aggregate_type, snapshot_data, version) do
    with {:ok, connection} <- Client.get_connection() do
      document_id = "#{aggregate_id}_v#{version}"
      document_path = document_path(@snapshots_collection, document_id)

      document = %Document{
        name: document_path,
        fields: %{
          "aggregate_id" => %Value{stringValue: aggregate_id},
          "aggregate_type" => %Value{stringValue: aggregate_type},
          "version" => %Value{integerValue: to_string(version)},
          "snapshot_data" => encode_value(snapshot_data),
          "created_at" => %Value{timestampValue: DateTime.utc_now() |> DateTime.to_iso8601()}
        }
      }

      case Projects.firestore_projects_databases_documents_patch(
             connection,
             document_path,
             body: document
           ) do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  最新のスナップショットを取得する
  """
  def get_latest_snapshot(aggregate_id) do
    with {:ok, connection} <- Client.get_connection() do
      # スナップショットを最新バージョン順で取得
      query = %{
        structuredQuery: %{
          from: [%{collectionId: @snapshots_collection}],
          where: %{
            fieldFilter: %{
              field: %{fieldPath: "aggregate_id"},
              op: "EQUAL",
              value: %{stringValue: aggregate_id}
            }
          },
          orderBy: [
            %{
              field: %{fieldPath: "version"},
              direction: "DESCENDING"
            }
          ],
          limit: 1
        }
      }

      case run_firestore_query(connection, query) do
        {:ok, [document | _]} ->
          {:ok, decode_snapshot(document)}

        {:ok, []} ->
          {:ok, nil}

        error ->
          error
      end
    end
  end

  @doc """
  指定されたイベントID以降のイベントを取得する
  """
  def get_events_after(after_event_id, limit \\ 100) do
    with {:ok, connection} <- Client.get_connection() do
      # created_at でソートして after_event_id より後のイベントを取得
      query = %{
        structuredQuery: %{
          from: [%{collectionId: @events_collection}],
          orderBy: [
            %{
              field: %{fieldPath: "created_at"},
              direction: "ASCENDING"
            }
          ],
          limit: limit
        }
      }

      case run_firestore_query(connection, query) do
        {:ok, documents} ->
          events = Enum.map(documents, &decode_event/1)
          # after_event_id より後のイベントをフィルタ
          filtered =
            if after_event_id do
              Enum.drop_while(events, fn event ->
                event.event_id != after_event_id
              end)
              |> Enum.drop(1)
            else
              events
            end

          {:ok, filtered}

        error ->
          error
      end
    end
  end

  # Private functions

  defp verify_version(connection, aggregate_id, expected_version) do
    case get_latest_event_version(connection, aggregate_id) do
      {:ok, current_version} when current_version == expected_version ->
        {:ok, current_version}

      {:ok, _different_version} ->
        {:error, :version_conflict}

      {:error, :not_found} when expected_version == 0 ->
        {:ok, 0}

      {:error, :not_found} ->
        {:error, :version_conflict}

      error ->
        error
    end
  end

  defp get_latest_event_version(connection, aggregate_id) do
    query = %{
      structuredQuery: %{
        from: [%{collectionId: @events_collection}],
        where: %{
          fieldFilter: %{
            field: %{fieldPath: "aggregate_id"},
            op: "EQUAL",
            value: %{stringValue: aggregate_id}
          }
        },
        orderBy: [
          %{
            field: %{fieldPath: "event_version"},
            direction: "DESCENDING"
          }
        ],
        limit: 1
      }
    }

    case run_firestore_query(connection, query) do
      {:ok, [document | _]} ->
        event = decode_event(document)
        {:ok, event.event_version}

      {:ok, []} ->
        {:error, :not_found}

      error ->
        error
    end
  end

  defp save_events_batch(connection, aggregate_id, aggregate_type, events, base_version) do
    # バッチ書き込みの実装
    # TODO: Firestore のトランザクション API を使用してアトミックに保存
    Enum.reduce_while(events, {:ok, base_version}, fn event, {:ok, version} ->
      new_version = version + 1

      case save_single_event(connection, aggregate_id, aggregate_type, event, new_version) do
        {:ok, _} -> {:cont, {:ok, new_version}}
        error -> {:halt, error}
      end
    end)
  end

  defp save_single_event(connection, aggregate_id, aggregate_type, event, version) do
    document_id = "#{aggregate_id}_v#{version}_#{UUID.uuid4()}"
    document_path = document_path(@events_collection, document_id)

    document = %Document{
      name: document_path,
      fields: %{
        "aggregate_id" => %Value{stringValue: aggregate_id},
        "aggregate_type" => %Value{stringValue: aggregate_type},
        "event_type" => %Value{stringValue: to_string(event.__struct__)},
        "event_data" => encode_value(Map.from_struct(event)),
        "event_version" => %Value{integerValue: to_string(version)},
        "created_at" => %Value{timestampValue: DateTime.utc_now() |> DateTime.to_iso8601()}
      }
    }

    Projects.firestore_projects_databases_documents_create_document(
      connection,
      collection_parent_path(@events_collection),
      document_id,
      body: document
    )
  end

  defp query_events(connection, aggregate_id, after_version) do
    query = %{
      structuredQuery: %{
        from: [%{collectionId: @events_collection}],
        where: %{
          compositeFilter: %{
            op: "AND",
            filters: [
              %{
                fieldFilter: %{
                  field: %{fieldPath: "aggregate_id"},
                  op: "EQUAL",
                  value: %{stringValue: aggregate_id}
                }
              },
              %{
                fieldFilter: %{
                  field: %{fieldPath: "event_version"},
                  op: "GREATER_THAN",
                  value: %{integerValue: to_string(after_version)}
                }
              }
            ]
          }
        },
        orderBy: [
          %{
            field: %{fieldPath: "event_version"},
            direction: "ASCENDING"
          }
        ]
      }
    }

    case run_firestore_query(connection, query) do
      {:ok, documents} ->
        events = Enum.map(documents, &decode_event/1)
        {:ok, events}

      error ->
        error
    end
  end

  defp run_firestore_query(connection, query) do
    project_id = Client.get_project_id(:shared)
    parent = "projects/#{project_id}/databases/(default)/documents"

    case Projects.firestore_projects_databases_documents_run_query(
           connection,
           parent,
           body: query
         ) do
      {:ok, responses} ->
        documents =
          Enum.flat_map(responses, fn response ->
            case response do
              %{document: doc} when not is_nil(doc) -> [doc]
              _ -> []
            end
          end)

        {:ok, documents}

      error ->
        Logger.error("Firestore query failed: #{inspect(error)}")
        error
    end
  end

  defp decode_event(document) do
    fields =
      case document do
        %{fields: f} -> f
        %{"fields" => f} -> f
        _ -> %{}
      end

    %{
      event_id: Map.get(document, "name", "") |> String.split("/") |> List.last(),
      aggregate_id: get_field_value(fields, "aggregate_id", :string),
      aggregate_type: get_field_value(fields, "aggregate_type", :string),
      event_type: get_field_value(fields, "event_type", :string),
      event_data: decode_value(Map.get(fields, "event_data", %{})),
      event_version: get_field_value(fields, "event_version", :integer),
      created_at: get_field_value(fields, "created_at", :timestamp)
    }
  end

  defp decode_snapshot(document) do
    fields =
      case document do
        %{fields: f} -> f
        %{"fields" => f} -> f
        _ -> %{}
      end

    %{
      aggregate_id: get_field_value(fields, "aggregate_id", :string),
      aggregate_type: get_field_value(fields, "aggregate_type", :string),
      version: get_field_value(fields, "version", :integer),
      snapshot_data: decode_value(Map.get(fields, "snapshot_data", %{})),
      created_at: get_field_value(fields, "created_at", :timestamp)
    }
  end

  defp get_field_value(fields, field_name, type) do
    case Map.get(fields, field_name) do
      nil -> nil
      value -> decode_field_value(value, type)
    end
  end

  defp decode_field_value(%{"stringValue" => value}, :string), do: value
  defp decode_field_value(%{stringValue: value}, :string), do: value
  defp decode_field_value(%{"integerValue" => value}, :integer), do: String.to_integer(value)
  defp decode_field_value(%{integerValue: value}, :integer), do: String.to_integer(value)
  defp decode_field_value(%{"timestampValue" => value}, :timestamp), do: decode_timestamp(value)
  defp decode_field_value(%{timestampValue: value}, :timestamp), do: decode_timestamp(value)
  defp decode_field_value(_, _), do: nil

  defp document_path(collection, document_id) do
    project_id = Client.get_project_id(:shared)
    "projects/#{project_id}/databases/(default)/documents/#{collection}/#{document_id}"
  end

  defp collection_parent_path(_collection) do
    project_id = Client.get_project_id(:shared)
    "projects/#{project_id}/databases/(default)/documents"
  end

  # エンコード/デコード関数

  defp encode_value(value) when is_binary(value), do: %Value{stringValue: value}
  defp encode_value(value) when is_integer(value), do: %Value{integerValue: to_string(value)}
  defp encode_value(value) when is_float(value), do: %Value{doubleValue: value}
  defp encode_value(value) when is_boolean(value), do: %Value{booleanValue: value}
  defp encode_value(nil), do: %Value{nullValue: "NULL_VALUE"}

  defp encode_value(%DateTime{} = value) do
    %Value{timestampValue: DateTime.to_iso8601(value)}
  end

  defp encode_value(value) when is_map(value) do
    %Value{
      mapValue: %MapValue{
        fields:
          Map.new(value, fn {k, v} ->
            {to_string(k), encode_value(v)}
          end)
      }
    }
  end

  defp encode_value(value) when is_list(value) do
    %Value{
      arrayValue: %ArrayValue{
        values: Enum.map(value, &encode_value/1)
      }
    }
  end

  defp decode_value(%{"stringValue" => value}), do: value
  defp decode_value(%{"integerValue" => value}), do: String.to_integer(value)
  defp decode_value(%{"doubleValue" => value}), do: value
  defp decode_value(%{"booleanValue" => value}), do: value
  defp decode_value(%{"nullValue" => _}), do: nil

  defp decode_value(%{"timestampValue" => value}) do
    decode_timestamp(value)
  end

  defp decode_value(%{"mapValue" => %{"fields" => fields}}) do
    Map.new(fields, fn {k, v} -> {k, decode_value(v)} end)
  end

  defp decode_value(%{"arrayValue" => %{"values" => values}}) do
    Enum.map(values, &decode_value/1)
  end

  defp decode_value(value), do: value

  defp decode_timestamp(timestamp_string) do
    case DateTime.from_iso8601(timestamp_string) do
      {:ok, datetime, _} -> datetime
      _ -> timestamp_string
    end
  end

  @doc """
  イベントを保存する（EventStoreAdapter インターフェース用）
  """
  def save_events(aggregate_id, events, expected_version, _metadata \\ %{}) do
    # aggregate_type を取得（最初のイベントから推測）
    aggregate_type = 
      case events do
        [%{aggregate_type: type} | _] -> type
        [%{__struct__: module} | _] -> 
          module 
          |> Module.split()
          |> Enum.take(-2)
          |> List.first()
          |> to_string()
        _ -> "Unknown"
      end

    save_events(aggregate_id, aggregate_type, events, expected_version)
  end

  @doc """
  イベントを取得する（EventStoreAdapter インターフェース用）
  """
  def get_events(aggregate_id, after_version) do
    get_events(aggregate_id, after_version)
  end
end

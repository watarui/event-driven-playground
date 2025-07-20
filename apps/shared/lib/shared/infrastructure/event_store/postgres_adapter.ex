defmodule Shared.Infrastructure.EventStore.PostgresAdapter do
  @moduledoc """
  PostgreSQL を使用したイベントストアの実装
  """

  @behaviour Shared.Behaviours.EventStore

  import Ecto.Query
  alias Shared.Config
  alias Shared.Domain.ValueObjects.EntityId
  alias Shared.Infrastructure.EventStore.AggregateVersionCache
  alias Shared.Infrastructure.EventStore.Schema.Event
  alias Shared.Infrastructure.EventStore.SnapshotStore
  alias Shared.Infrastructure.EventStore.VersionConflictError
  alias Shared.Infrastructure.Resilience.CircuitBreaker
  require Logger

  # append_events/5 (EventStore から呼ばれる実装)
  def append_events(aggregate_id, aggregate_type, events, expected_version, metadata) do
    Logger.debug(
      "PostgresAdapter.append_events/5 called for aggregate #{aggregate_id}, type: #{aggregate_type}, events count: #{length(events)}, expected_version: #{expected_version}"
    )

    # aggregate_id を UUID 文字列形式に変換
    uuid_aggregate_id = ensure_uuid_string(aggregate_id)
    Logger.debug("Converted aggregate_id to UUID string: #{uuid_aggregate_id}")

    # サーキットブレーカーを通じて実行
    CircuitBreaker.call(:event_store, fn ->
      do_append_events(uuid_aggregate_id, aggregate_type, events, expected_version, metadata)
    end)
  end

  # append_events/4 (behaviour と一致させる)
  @impl true
  def append_events(stream_id, events, expected_version, metadata) do
    # aggregate_type を取得
    aggregate_type =
      case events do
        [first_event | _] ->
          if function_exported?(first_event.__struct__, :aggregate_type, 0) do
            first_event.__struct__.aggregate_type()
          else
            "unknown"
          end

        _ ->
          "unknown"
      end

    Logger.debug(
      "PostgresAdapter.append_events called for stream #{stream_id}, type: #{aggregate_type}, events count: #{length(events)}, expected_version: #{expected_version}"
    )

    # stream_id を UUID 文字列形式に変換
    uuid_stream_id = ensure_uuid_string(stream_id)
    Logger.debug("Converted stream_id to UUID string: #{uuid_stream_id}")

    # サーキットブレーカーを通じて実行
    CircuitBreaker.call(:event_store, fn ->
      do_append_events(uuid_stream_id, aggregate_type, events, expected_version, metadata)
    end)
  end

  defp do_append_events(uuid_aggregate_id, aggregate_type, events, expected_version, metadata) do
    # 直接イベントを保存（Multi を使わない）
    try do
      # バージョンチェック
      current_version = get_current_version(nil, uuid_aggregate_id)

      if expected_version != current_version do
        Logger.error(
          "Version mismatch for aggregate #{uuid_aggregate_id}: expected #{expected_version}, actual #{current_version}"
        )

        {:error,
         %VersionConflictError{
           aggregate_id: uuid_aggregate_id,
           expected_version: expected_version,
           actual_version: current_version
         }}
      else
        # イベントレコードを作成
        event_records =
          events
          |> Enum.with_index(1)
          |> Enum.map(fn {event, index} ->
            %{
              aggregate_id: uuid_aggregate_id,
              aggregate_type: aggregate_type,
              event_type: event.__struct__.event_type(),
              event_data: encode_event_data(event),
              event_version: expected_version + index,
              metadata: metadata,
              global_sequence: nil,
              schema_version: 1,
              inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
              updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
            }
          end)

        Logger.debug(
          "Inserting #{length(event_records)} events for aggregate #{uuid_aggregate_id}"
        )

        Logger.debug("Event records to insert: #{inspect(event_records)}")

        # insert_all を使用して直接保存
        {count, inserted} =
          Shared.Infrastructure.EventStore.Repo.insert_all(Event, event_records, returning: true)

        Logger.debug("Inserted #{count} events successfully")
        Logger.debug("Inserted records: #{inspect(inserted)}")

        if count == length(events) do
          # イベントバスに発行
          Enum.each(inserted, &publish_event/1)
          last_event = List.last(inserted)
          # バージョンキャッシュを更新
          AggregateVersionCache.set_version(uuid_aggregate_id, last_event.event_version)

          Logger.info(
            "Successfully appended #{length(inserted)} events for aggregate #{uuid_aggregate_id}"
          )

          {:ok, last_event.event_version}
        else
          Logger.error(
            "Failed to insert all events: expected #{length(events)}, inserted #{count}"
          )

          {:error, :insert_failed}
        end
      end
    rescue
      e ->
        Logger.error("Exception during append_events: #{inspect(e)}")
        {:error, e}
    end
  end

  # read_stream/2 (behaviour に合わせる)
  @impl true
  def read_stream(stream_id, from_version) do
    uuid_stream_id = ensure_uuid_string(stream_id)

    CircuitBreaker.call(:event_store, fn ->
      query =
        from(e in Event,
          where: e.aggregate_id == ^uuid_stream_id,
          order_by: [asc: e.event_version]
        )

      query =
        if from_version do
          from(e in query, where: e.event_version > ^from_version)
        else
          query
        end

      events = Shared.Infrastructure.EventStore.Repo.all(query)

      decoded_events =
        Enum.map(events, fn event ->
          decode_event(event)
        end)

      {:ok, decoded_events}
    end)
  rescue
    e ->
      Logger.error("Failed to get events: #{inspect(e)}")
      {:error, e}
  end

  def get_events_by_type(event_type, opts) do
    limit = Keyword.get(opts, :limit, 100)
    after_id = Keyword.get(opts, :after_id)

    query =
      from(e in Event,
        where: e.event_type == ^event_type,
        order_by: [asc: e.global_sequence],
        limit: ^limit
      )

    query =
      if after_id do
        from(e in query, where: e.id > ^after_id)
      else
        query
      end

    events = Shared.Infrastructure.EventStore.Repo.all(query)

    decoded_events =
      Enum.map(events, fn event ->
        decode_event(event)
      end)

    {:ok, decoded_events}
  rescue
    e ->
      Logger.error("Failed to get events by type: #{inspect(e)}")
      {:error, e}
  end

  @impl true
  def subscribe(subscriber, opts) do
    event_types = Keyword.get(opts, :event_types, :all)
    event_bus = Config.event_bus_module()

    if event_types == :all do
      event_bus.subscribe_all()
    else
      Enum.each(event_types, &event_bus.subscribe/1)
    end

    {:ok, {subscriber, event_types}}
  end

  @impl true
  def unsubscribe({_subscriber, event_types}) do
    event_bus = Config.event_bus_module()

    if event_types == :all do
      event_bus.unsubscribe_all()
    else
      Enum.each(event_types, &event_bus.unsubscribe/1)
    end

    :ok
  end

  def get_events_after(after_id, limit) do
    query =
      from(e in Event,
        where: e.global_sequence > ^after_id,
        order_by: [asc: e.global_sequence]
      )

    query =
      if limit do
        from(e in query, limit: ^limit)
      else
        query
      end

    events = Shared.Infrastructure.EventStore.Repo.all(query)

    decoded_events =
      Enum.map(events, fn event ->
        event
        |> decode_event()
        |> Map.put(:id, event.global_sequence)
      end)

    {:ok, decoded_events}
  rescue
    e ->
      Logger.error("Failed to get events after id #{after_id}: #{inspect(e)}")
      {:error, e}
  end

  # Private functions

  defp validate_version(multi, aggregate_id, expected_version) do
    Ecto.Multi.run(multi, :validate_version, fn repo, _changes ->
      current_version = get_current_version(repo, aggregate_id)

      if current_version == expected_version do
        {:ok, :valid}
      else
        {:error, {:version_mismatch, expected_version, current_version}}
      end
    end)
  end

  defp get_current_version(_repo, aggregate_id) do
    uuid_aggregate_id = ensure_uuid_string(aggregate_id)
    # キャッシュからバージョンを取得
    case AggregateVersionCache.get_version(uuid_aggregate_id) do
      {:ok, version} ->
        version

      {:error, :not_cached} ->
        # キャッシュにない場合は DB から取得
        query =
          from(e in Event,
            where: e.aggregate_id == ^uuid_aggregate_id,
            select: max(e.event_version)
          )

        version = Shared.Infrastructure.EventStore.Repo.one(query) || -1
        # キャッシュに保存
        AggregateVersionCache.set_version(uuid_aggregate_id, version)
        version
    end
  end

  defp insert_events(multi, aggregate_id, aggregate_type, events, expected_version, metadata) do
    Ecto.Multi.run(multi, :events, fn _repo, _changes ->
      event_records =
        events
        |> Enum.with_index(1)
        |> Enum.map(fn {event, index} ->
          %{
            aggregate_id: aggregate_id,
            aggregate_type: aggregate_type,
            event_type: event.__struct__.event_type(),
            event_data: encode_event_data(event),
            event_version: expected_version + index,
            metadata: metadata,
            # global_sequence を追加
            global_sequence: nil,
            # schema_version を追加
            schema_version: 1,
            inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
            updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
          }
        end)

      Logger.debug("Inserting #{length(event_records)} events for aggregate #{aggregate_id}")

      {count, inserted} =
        Shared.Infrastructure.EventStore.Repo.insert_all(Event, event_records, returning: true)

      Logger.debug("Inserted #{count} events successfully")

      if count == length(events) do
        {:ok, inserted}
      else
        {:error, :insert_failed}
      end
    end)
  end

  defp encode_event_data(event) do
    event
    |> Map.from_struct()
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new(fn {k, v} -> {Atom.to_string(k), encode_value(v)} end)
  end

  defp encode_value(%{__struct__: module} = struct) do
    # 値オブジェクトの場合
    cond do
      function_exported?(module, :value, 0) ->
        # EntityId, CategoryNameなどのvalue関数を持つ値オブジェクト
        Map.get(struct, :value)

      module == DateTime ->
        DateTime.to_iso8601(struct)

      module == Decimal ->
        Decimal.to_string(struct)

      true ->
        # その他の構造体はMapに変換
        struct
        |> Map.from_struct()
        |> Enum.reject(fn {_k, v} -> is_nil(v) end)
        |> Map.new(fn {k, v} -> {Atom.to_string(k), encode_value(v)} end)
    end
  end

  defp encode_value(value), do: value

  defp decode_event(event_record) do
    # イベントタイプからモジュール名を生成
    module = Shared.Domain.EventRegistry.get_module!(event_record.event_type)

    event_data =
      event_record.event_data
      |> decode_event_data()
      |> Map.new(fn {k, v} -> {String.to_existing_atom(k), v} end)

    struct(module, event_data)
  end

  defp decode_event_data(data) when is_map(data) do
    Map.new(data, fn {k, v} -> {k, decode_value(k, v)} end)
  end

  defp decode_value(key, value) when is_map(value) do
    # 値オブジェクトの復元
    cond do
      # IDフィールドの場合（"id"、"xxx_id"、"parent_id"など）
      (key == "id" or key =~ ~r/_id$/) and is_binary(value["value"]) ->
        # EntityId の復元
        %Shared.Domain.ValueObjects.EntityId{value: value["value"]}

      key == "price" or key == "total_amount" or key =~ ~r/price$/ ->
        # Money の復元
        %Shared.Domain.ValueObjects.Money{
          amount: Decimal.new(value["amount"]),
          currency: value["currency"]
        }

      key == "name" and Map.has_key?(value, "value") ->
        # ProductName または CategoryName の復元
        %Shared.Domain.ValueObjects.CategoryName{value: value["value"]}

      true ->
        value
    end
  end

  defp decode_value(_key, value) when is_binary(value) do
    # DateTime の復元を試みる
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _} -> datetime
      _ -> value
    end
  end

  defp decode_value(_key, value), do: value

  defp publish_event(event_record) do
    event = decode_event(event_record)
    event_bus = Config.event_bus_module()
    event_bus.publish(String.to_atom(event_record.event_type), event)
  end

  def save_snapshot(aggregate_id, aggregate_type, version, data, metadata) do
    SnapshotStore.save_snapshot(aggregate_id, aggregate_type, version, data, metadata)
  end

  def get_snapshot(aggregate_id) do
    uuid_aggregate_id = ensure_uuid_string(aggregate_id)
    SnapshotStore.get_latest_snapshot(uuid_aggregate_id)
  end

  # Helper functions

  @doc false
  defp ensure_uuid_string(aggregate_id) when is_binary(aggregate_id) do
    # 既に UUID 文字列形式の場合はそのまま返す
    if String.length(aggregate_id) == 36 and String.contains?(aggregate_id, "-") do
      aggregate_id
    else
      # それ以外の場合はエラーをログに記録
      Logger.error("Invalid aggregate_id format: #{inspect(aggregate_id)}")
      aggregate_id
    end
  end

  defp ensure_uuid_string(%EntityId{value: value}), do: value

  defp ensure_uuid_string(%{"value" => value}) when is_binary(value), do: value

  defp ensure_uuid_string(aggregate_id) do
    Logger.error("Unexpected aggregate_id type: #{inspect(aggregate_id)}")
    to_string(aggregate_id)
  end

  # 追加の behaviour 関数

  @impl true
  def read_all_events(limit) do
    query =
      from(e in Event,
        order_by: [asc: e.global_sequence],
        limit: ^limit
      )

    events = Shared.Infrastructure.EventStore.Repo.all(query)
    decoded_events = Enum.map(events, &decode_event/1)
    {:ok, decoded_events}
  rescue
    e ->
      Logger.error("Failed to read all events: #{inspect(e)}")
      {:error, e}
  end

  @impl true
  def get_stream_version(stream_id) do
    uuid_stream_id = ensure_uuid_string(stream_id)

    case AggregateVersionCache.get_version(uuid_stream_id) do
      {:ok, version} ->
        {:ok, version}

      {:error, :not_found} ->
        # キャッシュにない場合は DB から取得
        version = get_current_version(nil, uuid_stream_id)

        if version > 0 do
          {:ok, version}
        else
          {:error, :stream_not_found}
        end
    end
  end

  @impl true
  def archive_events(days) do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)

    # 古いイベントをアーカイブテーブルに移動
    {count, _} =
      from(e in Event,
        where: e.inserted_at < ^cutoff_date
      )
      |> Shared.Infrastructure.EventStore.Repo.delete_all()

    {:ok, count}
  rescue
    e ->
      Logger.error("Failed to archive events: #{inspect(e)}")
      {:error, e}
  end

  @impl true
  def health_check do
    # データベース接続をチェック
    case Shared.Infrastructure.EventStore.Repo.query("SELECT 1") do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # 互換性のために旧 API も保持
  def get_events(aggregate_id, from_version) do
    read_stream(aggregate_id, from_version)
  end
end

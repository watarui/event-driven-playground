defmodule Shared.Infrastructure.EventStore.EventStore do
  @moduledoc """
  イベントストアのインターフェース

  イベントの永続化と取得の抽象化レイヤーを提供します
  """

  @type event :: struct()
  @type aggregate_id :: String.t()
  @type aggregate_type :: String.t()
  @type event_version :: integer()
  @type event_metadata :: map()

  @doc """
  イベントストアの動作を定義するビヘイビア
  """
  @callback append_events(
              aggregate_id(),
              aggregate_type(),
              [event()],
              event_version(),
              event_metadata()
            ) :: {:ok, event_version()} | {:error, term()}

  @callback get_events(
              aggregate_id(),
              from_version :: event_version() | nil
            ) :: {:ok, [event()]} | {:error, term()}

  @callback get_events_by_type(
              event_type :: String.t(),
              opts :: keyword()
            ) :: {:ok, [event()]} | {:error, term()}

  @callback subscribe(
              subscriber :: pid(),
              opts :: keyword()
            ) :: {:ok, subscription :: term()} | {:error, term()}

  @callback unsubscribe(subscription :: term()) :: :ok | {:error, term()}

  @callback get_events_after(
              after_id :: integer(),
              limit :: integer() | nil
            ) :: {:ok, [event()]} | {:error, term()}

  @callback save_snapshot(
              aggregate_id(),
              aggregate_type(),
              version :: integer(),
              data :: map(),
              metadata :: map()
            ) :: {:ok, map()} | {:error, term()}

  @callback get_snapshot(aggregate_id()) :: {:ok, map()} | {:error, :not_found} | {:error, term()}

  @doc """
  使用するアダプターを取得する
  """
  def adapter do
    adapter_module =
      case Shared.Config.database_adapter() do
        :firestore ->
          Shared.Infrastructure.Firestore.EventStoreAdapter
        _ ->
          Application.get_env(
            :shared,
            :event_store_adapter,
            Shared.Infrastructure.EventStore.PostgresAdapter
          )
      end

    require Logger
    Logger.debug("EventStore using adapter: #{inspect(adapter_module)}")
    adapter_module
  end

  @doc """
  イベントを追加する
  """
  def append_events(aggregate_id, aggregate_type, events, expected_version, metadata \\ %{}) do
    require Logger

    Logger.debug(
      "EventStore.append_events called with aggregate_id: #{aggregate_id}, type: #{aggregate_type}, events: #{length(events)}"
    )

    adapter().append_events(aggregate_id, aggregate_type, events, expected_version, metadata)
  end

  @doc """
  アグリゲートのイベントを取得する
  """
  def get_events(aggregate_id, from_version \\ nil) do
    adapter().get_events(aggregate_id, from_version)
  end

  @doc """
  特定タイプのイベントを取得する
  """
  def get_events_by_type(event_type, opts \\ []) do
    adapter().get_events_by_type(event_type, opts)
  end

  @doc """
  イベントを購読する
  """
  def subscribe(subscriber, opts \\ []) do
    adapter().subscribe(subscriber, opts)
  end

  @doc """
  購読を解除する
  """
  def unsubscribe(subscription) do
    adapter().unsubscribe(subscription)
  end

  @doc """
  指定したID以降のイベントを取得する
  """
  def get_events_after(after_id, limit \\ nil) do
    adapter().get_events_after(after_id, limit)
  end

  @doc """
  スナップショットを保存する
  """
  def save_snapshot(aggregate_id, aggregate_type, version, data, metadata \\ %{}) do
    adapter().save_snapshot(aggregate_id, aggregate_type, version, data, metadata)
  end

  @doc """
  最新のスナップショットを取得する
  """
  def get_snapshot(aggregate_id) do
    adapter().get_snapshot(aggregate_id)
  end

  @doc """
  トランザクション内で処理を実行する
  """
  def transaction(fun) do
    # アダプターがトランザクションをサポートしている場合は使用
    if function_exported?(adapter(), :transaction, 1) do
      adapter().transaction(fun)
    else
      # サポートしていない場合は直接実行
      try do
        {:ok, fun.()}
      rescue
        e -> {:error, e}
      end
    end
  end
end

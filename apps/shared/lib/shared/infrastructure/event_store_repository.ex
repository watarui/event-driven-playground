defmodule Shared.Infrastructure.EventStoreRepository do
  @moduledoc """
  イベントストア専用のリポジトリビヘイビア
  
  CQRS/イベントソーシングパターンに特化したインターフェースを提供します。
  """

  alias Shared.Domain.Event

  @type aggregate_id :: String.t()
  @type event :: Event.t()
  @type version :: non_neg_integer()
  @type error :: {:error, term()}

  @doc """
  イベントを追加
  """
  @callback append_events(aggregate_id :: aggregate_id(), events :: [event()]) ::
              {:ok, version()} | error()

  @doc """
  集約のイベントを取得
  """
  @callback get_events(aggregate_id :: aggregate_id(), opts :: keyword()) ::
              {:ok, [event()]} | error()

  @doc """
  特定バージョン以降のイベントを取得
  """
  @callback get_events_after_version(aggregate_id :: aggregate_id(), version :: version()) ::
              {:ok, [event()]} | error()

  @doc """
  全イベントをストリーミング（プロジェクション構築用）
  """
  @callback stream_all_events(opts :: keyword()) :: Enumerable.t()

  @doc """
  スナップショットを保存
  """
  @callback save_snapshot(aggregate_id :: aggregate_id(), snapshot :: map(), version :: version()) ::
              :ok | error()

  @doc """
  最新のスナップショットを取得
  """
  @callback get_latest_snapshot(aggregate_id :: aggregate_id()) ::
              {:ok, {snapshot :: map(), version :: version()}} | {:error, :not_found} | error()
end
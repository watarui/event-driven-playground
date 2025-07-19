defmodule Shared.Domain.Aggregate.Base do
  @moduledoc """
  アグリゲートの基底モジュール

  Event Sourcing パターンにおけるアグリゲートの共通機能を提供します
  """

  @type aggregate_id :: String.t()
  @type event :: struct()
  @type aggregate :: struct()

  @callback new() :: aggregate()
  @callback apply_event(aggregate(), event()) :: aggregate()
  @callback aggregate_type() :: String.t()

  defmacro __using__(_opts) do
    quote do
      @behaviour Shared.Domain.Aggregate.Base

      # 型定義を共有
      @type aggregate_id :: String.t()
      @type event :: struct()
      @type aggregate :: struct()

      @doc """
      イベントのリストからアグリゲートを再構築する
      """
      @spec rebuild_from_events([event()]) :: aggregate()
      def rebuild_from_events(events) do
        Enum.reduce(events, new(), &apply_event(&2, &1))
      end

      @doc """
      スナップショットとイベントからアグリゲートを再構築する
      """
      @spec rebuild_from_snapshot_and_events(map(), [event()]) :: aggregate()
      def rebuild_from_snapshot_and_events(snapshot_data, events) do
        aggregate = from_snapshot(snapshot_data)
        Enum.reduce(events, aggregate, &apply_event(&2, &1))
      end

      @doc """
      アグリゲートをスナップショット用のデータに変換する
      """
      @spec to_snapshot(aggregate()) :: map()
      def to_snapshot(aggregate) do
        aggregate
        |> Map.from_struct()
        |> Map.drop([:uncommitted_events])
      end

      @doc """
      スナップショットデータからアグリゲートを復元する
      """
      @spec from_snapshot(map()) :: aggregate()
      def from_snapshot(snapshot_data) do
        struct(__MODULE__, snapshot_data)
      end

      @doc """
      アグリゲートのバージョンを取得する
      """
      @spec get_version(aggregate()) :: integer()
      def get_version(aggregate) do
        Map.get(aggregate, :version, 0)
      end

      @doc """
      アグリゲートのバージョンをインクリメントする
      """
      @spec increment_version(aggregate()) :: aggregate()
      def increment_version(aggregate) do
        Map.update!(aggregate, :version, &(&1 + 1))
      end

      @doc """
      アグリゲートに未適用のイベントを追加する
      """
      @spec add_uncommitted_event(aggregate(), event()) :: aggregate()
      def add_uncommitted_event(aggregate, event) do
        uncommitted_events = Map.get(aggregate, :uncommitted_events, [])
        Map.put(aggregate, :uncommitted_events, uncommitted_events ++ [event])
      end

      @doc """
      未適用のイベントを取得してクリアする
      """
      @spec get_and_clear_uncommitted_events(aggregate()) :: {aggregate(), [event()]}
      def get_and_clear_uncommitted_events(aggregate) do
        events = Map.get(aggregate, :uncommitted_events, [])
        cleared_aggregate = Map.put(aggregate, :uncommitted_events, [])
        {cleared_aggregate, events}
      end

      @doc """
      イベントを適用してアグリゲートを更新する（副作用なし）
      """
      @spec apply_and_record_event(aggregate(), event()) :: aggregate()
      def apply_and_record_event(aggregate, event) do
        aggregate
        |> apply_event(event)
        |> increment_version()
        |> add_uncommitted_event(event)
      end

      # デフォルト実装を提供
      def new do
        raise "new/0 must be implemented by #{__MODULE__}"
      end

      def apply_event(_aggregate, _event) do
        raise "apply_event/2 must be implemented by #{__MODULE__}"
      end

      @doc """
      アグリゲートタイプを返す
      """
      def aggregate_type do
        __MODULE__
        |> Module.split()
        |> List.last()
        |> Macro.underscore()
      end

      defoverridable new: 0, apply_event: 2, to_snapshot: 1, from_snapshot: 1, aggregate_type: 0
    end
  end
end

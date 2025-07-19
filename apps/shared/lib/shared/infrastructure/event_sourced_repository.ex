defmodule Shared.Infrastructure.EventSourcedRepository do
  @moduledoc """
  イベントソーシングベースのリポジトリ実装

  Event Store を使用してアグリゲートの永続化を行う。
  """

  alias Shared.Infrastructure.EventStore
  alias Shared.Domain.ValueObjects.EntityId
  alias Shared.Config

  require Logger

  defmacro __using__(opts) do
    aggregate_module = Keyword.fetch!(opts, :aggregate)
    aggregate_type = Keyword.get(opts, :aggregate_type)

    quote do
      use Shared.Domain.Repository

      alias unquote(aggregate_module), as: Aggregate

      @aggregate_module unquote(aggregate_module)
      @aggregate_type unquote(aggregate_type)

      @impl true
      def aggregate_type, do: @aggregate_type

      @impl true
      def find_by_id(aggregate_id) do
        with {:ok, id_string} <- EntityId.to_string(aggregate_id),
             {:ok, events} <- EventStore.get_events(id_string) do
          if Enum.empty?(events) do
            {:error, :not_found}
          else
            aggregate = rebuild_aggregate(events)
            {:ok, aggregate}
          end
        end
      end

      @impl true
      def save(aggregate) do
        with :ok <- validate_aggregate(aggregate),
             {:ok, events} <- extract_uncommitted_events(aggregate),
             {:ok, id_string} <- EntityId.to_string(aggregate.id) do
          if Enum.empty?(events) do
            {:ok, aggregate}
          else
            case EventStore.append_events(
                   id_string,
                   @aggregate_type,
                   events,
                   aggregate.version
                 ) do
              {:ok, _} ->
                # イベントを発行
                event_bus = Config.event_bus_module()
                Enum.each(events, &event_bus.publish_event/1)

                # バージョンを更新してクリーンな状態のアグリゲートを返す
                updated_aggregate = %{
                  aggregate
                  | version: aggregate.version + length(events),
                    uncommitted_events: []
                }

                {:ok, updated_aggregate}

              {:error, :version_conflict} = error ->
                error

              {:error, reason} ->
                Logger.error("Failed to save aggregate: #{inspect(reason)}")
                {:error, reason}
            end
          end
        end
      end

      @impl true
      def delete(aggregate_id) do
        # イベントソーシングでは物理削除はしない
        # 代わりに削除イベントを追加する実装も可能
        Logger.warning(
          "Delete operation called on event-sourced repository for #{inspect(aggregate_id)}"
        )

        {:error, :not_supported}
      end

      @impl true
      def find_by(criteria, opts \\ []) do
        # イベントソーシングでは直接的なクエリは難しい
        # Read Model やプロジェクションを使用することを推奨
        Logger.warning("find_by is not efficient for event-sourced repositories")
        {:error, :not_supported}
      end

      @impl true
      def transaction(fun) do
        # EventStore のトランザクションに委譲
        EventStore.transaction(fun)
      end

      # Private functions

      defp rebuild_aggregate(events) do
        Enum.reduce(events, @aggregate_module.new(), fn event, aggregate ->
          apply_event(aggregate, event)
        end)
      end

      defp apply_event(aggregate, event) do
        if function_exported?(@aggregate_module, :apply_event, 2) do
          @aggregate_module.apply_event(aggregate, event)
        else
          # デフォルトの実装
          %{
            aggregate
            | version: aggregate.version + 1,
              updated_at: event.event_timestamp || DateTime.utc_now()
          }
        end
      end

      defp validate_aggregate(aggregate) do
        if is_struct(aggregate, @aggregate_module) do
          :ok
        else
          {:error, {:invalid_aggregate_type, aggregate.__struct__}}
        end
      end

      defp extract_uncommitted_events(aggregate) do
        case Map.get(aggregate, :uncommitted_events) do
          nil -> {:ok, []}
          events when is_list(events) -> {:ok, events}
          _ -> {:error, :invalid_uncommitted_events}
        end
      end

      # オーバーライド可能にする
      defoverridable find_by: 2, delete: 1
    end
  end
end

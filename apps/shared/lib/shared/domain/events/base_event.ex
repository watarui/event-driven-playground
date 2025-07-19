defmodule Shared.Domain.Events.BaseEvent do
  @moduledoc """
  すべてのドメインイベントの基底モジュール

  イベントの共通的な振る舞いと構造を定義します
  """

  @type event_metadata :: %{
          event_id: String.t(),
          event_type: String.t(),
          aggregate_id: String.t(),
          aggregate_type: String.t(),
          event_version: integer(),
          occurred_at: DateTime.t(),
          metadata: map()
        }

  @callback new(map()) :: struct()
  @callback event_type() :: String.t()
  @callback aggregate_type() :: String.t()

  defmacro __using__(_opts) do
    quote do
      @behaviour Shared.Domain.Events.BaseEvent

      @doc """
      イベントのメタデータを作成する
      """
      def create_metadata(aggregate_id, event_version, metadata \\ %{}) do
        %{
          event_id: UUID.uuid4(),
          event_type: event_type(),
          aggregate_id: aggregate_id,
          aggregate_type: aggregate_type(),
          event_version: event_version,
          occurred_at: DateTime.utc_now(),
          metadata: metadata
        }
      end

      @doc """
      イベントデータを Map に変換する
      """
      def to_map(event) do
        event
        |> Map.from_struct()
        |> Enum.reject(fn {_k, v} -> is_nil(v) end)
        |> Map.new()
      end

      defimpl Jason.Encoder do
        def encode(event, opts) do
          event
          |> Map.from_struct()
          |> Map.reject(fn {_k, v} -> is_nil(v) end)
          |> Jason.Encode.map(opts)
        end
      end
    end
  end
end

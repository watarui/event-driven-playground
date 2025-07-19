defmodule Shared.Domain.Saga.SagaBase do
  @moduledoc """
  サガの基底モジュール

  サガパターンの共通機能を提供します
  """

  @type saga_id :: String.t()
  @type saga_state :: :started | :processing | :compensating | :completed | :failed | :compensated
  @type command :: struct()
  @type event :: struct()

  @callback new(saga_id(), map()) :: map()
  @callback handle_event(event(), map()) :: {:ok, [command()]} | {:error, String.t()}
  @callback get_compensation_commands(map()) :: [command()]
  @callback completed?(map()) :: boolean()
  @callback failed?(map()) :: boolean()

  defmacro __using__(_opts) do
    quote do
      @behaviour Shared.Domain.Saga.SagaBase

      @doc """
      サガの状態を更新する
      """
      def update_state(saga, new_state) do
        %{saga | state: new_state, updated_at: DateTime.utc_now()}
      end

      @doc """
      処理済みイベントを記録する
      """
      def record_processed_event(saga, event) do
        event_id = get_event_id(event)
        processed_events = Map.get(saga, :processed_events, [])

        if event_id in processed_events do
          saga
        else
          %{
            saga
            | processed_events: [event_id | processed_events],
              last_event_id: event_id,
              updated_at: DateTime.utc_now()
          }
        end
      end

      @doc """
      ステップを完了として記録する
      """
      def complete_step(saga, step_name) do
        completed_steps = Map.get(saga, :completed_steps, [])

        if step_name in completed_steps do
          saga
        else
          %{saga | completed_steps: [step_name | completed_steps], updated_at: DateTime.utc_now()}
        end
      end

      @doc """
      失敗を記録する
      """
      def record_failure(saga, step_name, reason) do
        %{
          saga
          | state: :failed,
            failed_step: step_name,
            failure_reason: reason,
            failed_at: DateTime.utc_now(),
            updated_at: DateTime.utc_now()
        }
      end

      @doc """
      補償処理を開始する
      """
      def start_compensation(saga) do
        %{
          saga
          | state: :compensating,
            compensation_started_at: DateTime.utc_now(),
            updated_at: DateTime.utc_now()
        }
      end

      @doc """
      補償処理を完了する
      """
      def complete_compensation(saga) do
        %{
          saga
          | state: :compensated,
            compensation_completed_at: DateTime.utc_now(),
            updated_at: DateTime.utc_now()
        }
      end

      @doc """
      サガを完了する
      """
      def complete_saga(saga) do
        %{
          saga
          | state: :completed,
            completed_at: DateTime.utc_now(),
            updated_at: DateTime.utc_now()
        }
      end

      # Private helpers

      defp get_event_id(event) do
        cond do
          Map.has_key?(event, :event_id) -> event.event_id
          Map.has_key?(event, :id) -> event.id
          true -> UUID.uuid4()
        end
      end

      # デフォルト実装を提供
      def new(_saga_id, _initial_data) do
        raise "new/2 must be implemented by #{__MODULE__}"
      end

      def handle_event(_event, _saga) do
        raise "handle_event/2 must be implemented by #{__MODULE__}"
      end

      def get_compensation_commands(_saga) do
        raise "get_compensation_commands/1 must be implemented by #{__MODULE__}"
      end

      def completed?(_saga) do
        raise "completed?/1 must be implemented by #{__MODULE__}"
      end

      def failed?(_saga) do
        raise "failed?/1 must be implemented by #{__MODULE__}"
      end

      defoverridable new: 2,
                     handle_event: 2,
                     get_compensation_commands: 1,
                     completed?: 1,
                     failed?: 1
    end
  end
end

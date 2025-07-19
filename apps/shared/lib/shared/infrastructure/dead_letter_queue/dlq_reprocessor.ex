defmodule Shared.Infrastructure.DeadLetterQueue.DLQReprocessor do
  @moduledoc """
  デッドレターキューのメッセージを再処理するためのヘルパーモジュール
  """

  alias Shared.Infrastructure.DeadLetterQueue

  require Logger

  @doc """
  ProjectionManagerの失敗したイベントを再処理する
  """
  def reprocess_projection_events(opts \\ []) do
    status = Keyword.get(opts, :status, "pending")
    limit = Keyword.get(opts, :limit, 100)

    case DeadLetterQueue.list_messages(source: "projection_manager", status: status, limit: limit) do
      {:ok, messages} ->
        Logger.info("Found #{length(messages)} messages to reprocess")

        results =
          Enum.map(messages, fn message ->
            reprocess_single_projection_event(message)
          end)

        success_count = Enum.count(results, fn {status, _} -> status == :ok end)
        Logger.info("Reprocessed #{success_count}/#{length(messages)} messages successfully")

        {:ok, results}

      {:error, reason} ->
        Logger.error("Failed to list DLQ messages: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Sagaの失敗したコマンドを再処理する
  """
  def reprocess_saga_commands(opts \\ []) do
    status = Keyword.get(opts, :status, "pending")
    limit = Keyword.get(opts, :limit, 100)

    case DeadLetterQueue.list_messages(
           source: "saga_step_execution",
           status: status,
           limit: limit
         ) do
      {:ok, messages} ->
        Logger.info("Found #{length(messages)} saga commands to reprocess")

        results =
          Enum.map(messages, fn message ->
            reprocess_single_saga_command(message)
          end)

        success_count = Enum.count(results, fn {status, _} -> status == :ok end)
        Logger.info("Reprocessed #{success_count}/#{length(messages)} saga commands successfully")

        {:ok, results}

      {:error, reason} ->
        Logger.error("Failed to list DLQ messages: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  特定のメッセージIDを再処理する
  """
  def reprocess_by_id(message_id) do
    case DeadLetterQueue.list_messages([]) do
      {:ok, messages} ->
        message = Enum.find(messages, fn m -> m.id == message_id end)

        if message do
          case message.source do
            "projection_manager" -> reprocess_single_projection_event(message)
            "saga_step_execution" -> reprocess_single_saga_command(message)
            _ -> {:error, :unknown_source}
          end
        else
          {:error, :not_found}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private functions

  defp reprocess_single_projection_event(dlq_message) do
    with {:ok, payload} <- Jason.decode(dlq_message.message),
         projection_module <- Module.concat([payload["projection_module"]]),
         {:ok, event_data} <- Map.fetch(payload, "event") do
      DeadLetterQueue.reprocess(dlq_message.id, fn _original_message ->
        # ProjectionManagerの処理を直接呼び出す
        try do
          projection_module.handle_event(event_data)
          {:ok, :reprocessed}
        rescue
          e ->
            {:error, Exception.format(:error, e, __STACKTRACE__)}
        end
      end)
    else
      error ->
        Logger.error("Failed to decode DLQ message: #{inspect(error)}")
        {:error, error}
    end
  end

  defp reprocess_single_saga_command(dlq_message) do
    with {:ok, command} <- Jason.decode(dlq_message.message) do
      DeadLetterQueue.reprocess(dlq_message.id, fn _original_message ->
        # Sagaコマンドディスパッチャーを使用して再送信
        dispatcher =
          Application.get_env(
            :shared,
            :saga_command_dispatcher,
            Shared.Infrastructure.Saga.CommandDispatcher
          )

        try do
          dispatcher.dispatch_command(command)
          {:ok, :reprocessed}
        rescue
          e ->
            {:error, Exception.format(:error, e, __STACKTRACE__)}
        end
      end)
    else
      error ->
        Logger.error("Failed to decode DLQ command: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  DLQの統計情報を表示する
  """
  def show_stats do
    case DeadLetterQueue.get_stats() do
      {:ok, stats} ->
        IO.puts("\n=== Dead Letter Queue Statistics ===")
        IO.puts("Total enqueued: #{stats[:total_enqueued] || 0}")
        IO.puts("Total reprocessed: #{stats[:total_reprocessed] || 0}")
        IO.puts("Total deleted: #{stats[:total_deleted] || 0}")

        if stats[:by_status] do
          IO.puts("\nBy Status:")

          Enum.each(stats[:by_status], fn {status, count} ->
            IO.puts("  #{status}: #{count}")
          end)
        end

        if stats[:by_source] do
          IO.puts("\nBy Source:")

          Enum.each(stats[:by_source], fn {source, count} ->
            IO.puts("  #{source}: #{count}")
          end)
        end

        :ok

      {:error, reason} ->
        IO.puts("Failed to get stats: #{inspect(reason)}")
        {:error, reason}
    end
  end
end

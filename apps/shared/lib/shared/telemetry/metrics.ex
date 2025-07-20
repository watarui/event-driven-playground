defmodule Shared.Telemetry.Metrics do
  @moduledoc """
  シンプルなメトリクス収集ヘルパー
  """

  @doc """
  カウンターをインクリメント
  """
  def increment(metric_name, tags \\ %{}) do
    :telemetry.execute(
      [:event_driven_playground, metric_name],
      %{count: 1},
      tags
    )
  end

  @doc """
  実行時間を計測
  """
  def timing(metric_name, tags \\ %{}, fun) do
    start_time = System.monotonic_time(:millisecond)

    try do
      result = fun.()
      duration = System.monotonic_time(:millisecond) - start_time

      :telemetry.execute(
        [:event_driven_playground, metric_name, :timing],
        %{duration: duration},
        Map.put(tags, :status, :ok)
      )

      {:ok, result}
    rescue
      error ->
        duration = System.monotonic_time(:millisecond) - start_time

        :telemetry.execute(
          [:event_driven_playground, metric_name, :timing],
          %{duration: duration},
          Map.put(tags, :status, :error)
        )

        {:error, error}
    end
  end

  @doc """
  コマンド実行メトリクス
  """
  def command_executed(command_type, status \\ :ok) do
    :telemetry.execute(
      [:event_driven_playground, :command, :dispatched],
      %{count: 1},
      %{command_type: command_type, status: status}
    )
  end

  @doc """
  クエリ実行メトリクス
  """
  def query_executed(query_type, status \\ :ok) do
    :telemetry.execute(
      [:event_driven_playground, :query, :executed],
      %{count: 1},
      %{query_type: query_type, status: status}
    )
  end

  @doc """
  イベント発行メトリクス
  """
  def event_published(event_type) do
    :telemetry.execute(
      [:event_driven_playground, :event, :published],
      %{count: 1},
      %{event_type: event_type}
    )
  end

  @doc """
  Saga メトリクス
  """
  def saga_completed(saga_type, status \\ :completed) do
    :telemetry.execute(
      [:event_driven_playground, :saga, status],
      %{count: 1},
      %{saga_type: saga_type}
    )
  end
end

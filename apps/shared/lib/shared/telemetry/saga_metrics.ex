defmodule Shared.Telemetry.SagaMetrics do
  @moduledoc """
  サガ専用のメトリクス収集
  """

  use GenServer

  # 30秒ごとに更新
  @update_interval 30_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_update()
    {:ok, %{active_count: 0}}
  end

  @impl true
  def handle_info(:update_metrics, state) do
    # 現在はアクティブな Saga 数を 0 として報告
    # 実際の実装では SagaExecutor から情報を取得することを想定
    :telemetry.execute(
      [:event_driven_playground, :saga, :active],
      %{count: state.active_count},
      %{}
    )

    schedule_update()
    {:noreply, state}
  end

  defp schedule_update do
    Process.send_after(self(), :update_metrics, @update_interval)
  end
end

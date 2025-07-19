defmodule Shared.Health.Checks.MemoryCheck do
  @moduledoc """
  メモリ使用状況のヘルスチェック

  Erlang VM のメモリ使用状況を監視し、閾値を超えた場合に警告します。
  """

  require Logger

  # メモリ閾値（バイト）
  # 1GB
  @warning_threshold_mb 1024
  # 2GB
  @critical_threshold_mb 2048

  @doc """
  メモリ使用状況を確認
  """
  def check do
    memory_info = :erlang.memory()

    total_mb = memory_info[:total] / 1_048_576
    process_mb = memory_info[:processes] / 1_048_576
    binary_mb = memory_info[:binary] / 1_048_576
    ets_mb = memory_info[:ets] / 1_048_576

    details = %{
      total_mb: Float.round(total_mb, 2),
      process_mb: Float.round(process_mb, 2),
      binary_mb: Float.round(binary_mb, 2),
      ets_mb: Float.round(ets_mb, 2),
      process_count: :erlang.system_info(:process_count),
      port_count: :erlang.system_info(:port_count)
    }

    cond do
      total_mb > @critical_threshold_mb ->
        {:error, "Memory usage critical: #{Float.round(total_mb, 2)}MB", details}

      total_mb > @warning_threshold_mb ->
        {:degraded, "Memory usage high: #{Float.round(total_mb, 2)}MB", details}

      true ->
        {:ok, details}
    end
  end

  @doc """
  詳細なメモリ統計を取得
  """
  def detailed_stats do
    memory = :erlang.memory()

    %{
      memory: %{
        total: memory[:total],
        processes: memory[:processes],
        processes_used: memory[:processes_used],
        system: memory[:system],
        atom: memory[:atom],
        atom_used: memory[:atom_used],
        binary: memory[:binary],
        code: memory[:code],
        ets: memory[:ets]
      },
      system: %{
        process_count: :erlang.system_info(:process_count),
        process_limit: :erlang.system_info(:process_limit),
        port_count: :erlang.system_info(:port_count),
        port_limit: :erlang.system_info(:port_limit),
        schedulers: :erlang.system_info(:schedulers),
        schedulers_online: :erlang.system_info(:schedulers_online)
      },
      garbage_collection: get_gc_stats()
    }
  end

  defp get_gc_stats do
    gc_info = :erlang.system_info(:garbage_collection)

    %{
      min_heap_size: Keyword.get(gc_info, :min_heap_size),
      min_bin_vheap_size: Keyword.get(gc_info, :min_bin_vheap_size),
      fullsweep_after: Keyword.get(gc_info, :fullsweep_after)
    }
  rescue
    _ ->
      %{
        min_heap_size: nil,
        min_bin_vheap_size: nil,
        fullsweep_after: nil
      }
  end
end

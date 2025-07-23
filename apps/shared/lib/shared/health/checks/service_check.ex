defmodule Shared.Health.Checks.ServiceCheck do
  @moduledoc """
  各サービスの稼働状況チェック

  重要なGenServerやSupervisorの稼働状況を確認します。
  """

  require Logger

  # ノードに応じて動的にサービスリストを生成
  def critical_services do
    node_str = Atom.to_string(node())

    cond do
      String.contains?(node_str, "client") ->
        # Client Service では SagaExecutor は不要
        []

      String.contains?(node_str, "command") ->
        # Command Service では SagaExecutor と EventBus が必須
        [
          {:event_bus, Shared.Infrastructure.EventBus},
          {:saga_executor, Shared.Infrastructure.Saga.SagaExecutor}
        ]

      true ->
        # その他のノードでは EventBus のみ必須
        [{:event_bus, Shared.Infrastructure.EventBus}]
    end
  end

  def optional_services do
    base_services = [
      {:circuit_breaker_supervisor, Shared.Infrastructure.Resilience.CircuitBreakerSupervisor},
      {:event_archiver, Shared.Infrastructure.EventStore.EventArchiver}
    ]

    # ノードに応じて適切なサービスを追加
    node_str = Atom.to_string(node())

    cond do
      String.contains?(node_str, "client") ->
        base_services ++
          [
            {:event_bus, Shared.Infrastructure.EventBus},
            {:remote_command_bus, ClientService.Infrastructure.RemoteCommandBus},
            {:remote_query_bus, ClientService.Infrastructure.RemoteQueryBus}
          ]

      String.contains?(node_str, "command") ->
        base_services ++
          [
            {:command_bus, CommandService.Infrastructure.CommandBus}
          ]

      String.contains?(node_str, "query") ->
        base_services ++
          [
            {:query_bus, QueryService.Infrastructure.QueryBus}
          ]

      true ->
        base_services
    end
  end

  @doc """
  全サービスの稼働状況を確認
  """
  def check do
    critical_list = critical_services()
    optional_list = optional_services()

    critical_results = check_services(critical_list)
    optional_results = check_services(optional_list)

    all_results = Map.merge(critical_results, optional_results)

    critical_failures =
      critical_list
      |> Enum.filter(fn {name, _} ->
        Map.get(critical_results, name) != :running
      end)
      |> Enum.map(fn {name, _} -> name end)

    if Enum.empty?(critical_failures) do
      # オプショナルサービスの一部が停止している場合は degraded
      optional_failures =
        optional_list
        |> Enum.filter(fn {name, _} ->
          Map.get(optional_results, name) != :running
        end)

      if Enum.empty?(optional_failures) do
        {:ok, all_results}
      else
        {:degraded, "Optional services not running: #{inspect(optional_failures)}", all_results}
      end
    else
      {:error, "Critical services not running: #{inspect(critical_failures)}", all_results}
    end
  end

  defp check_services(services) do
    services
    |> Enum.map(fn {name, module} ->
      status = check_process(module)
      {name, status}
    end)
    |> Enum.into(%{})
  end

  defp check_process(module) do
    # EventBus は特殊なケース
    if module == Shared.Infrastructure.EventBus do
      check_pubsub(:event_bus_pubsub)
    else
      case Process.whereis(module) do
        nil ->
          # プロセス名で見つからない場合、Registry経由で探す
          case Registry.lookup(:service_registry, module) do
            [{pid, _}] when is_pid(pid) ->
              if Process.alive?(pid), do: :running, else: :dead

            _ ->
              :not_started
          end

        pid when is_pid(pid) ->
          if Process.alive?(pid), do: :running, else: :dead
      end
    end
  rescue
    _ -> :error
  end

  defp check_pubsub(pubsub_name) do
    # Phoenix.PubSub のプロセスを確認
    case Process.whereis(pubsub_name) do
      nil ->
        :not_started

      pid when is_pid(pid) ->
        if Process.alive?(pid), do: :running, else: :dead
    end
  rescue
    _ -> :error
  end
end

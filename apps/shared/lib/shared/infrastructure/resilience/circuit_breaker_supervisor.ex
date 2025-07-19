defmodule Shared.Infrastructure.Resilience.CircuitBreakerSupervisor do
  @moduledoc """
  サーキットブレーカーを管理するスーパーバイザー
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # サーキットブレーカー用のRegistry
      {Registry, keys: :unique, name: Shared.CircuitBreakerRegistry},

      # 各サービス用のサーキットブレーカー
      Supervisor.child_spec(
        {Shared.Infrastructure.Resilience.CircuitBreaker,
         name: :database, failure_threshold: 5, success_threshold: 3, timeout: 30_000},
        id: :circuit_breaker_database
      ),
      Supervisor.child_spec(
        {Shared.Infrastructure.Resilience.CircuitBreaker,
         name: :event_store, failure_threshold: 3, success_threshold: 2, timeout: 20_000},
        id: :circuit_breaker_event_store
      ),
      Supervisor.child_spec(
        {Shared.Infrastructure.Resilience.CircuitBreaker,
         name: :command_bus, failure_threshold: 5, success_threshold: 3, timeout: 30_000},
        id: :circuit_breaker_command_bus
      ),
      Supervisor.child_spec(
        {Shared.Infrastructure.Resilience.CircuitBreaker,
         name: :query_bus, failure_threshold: 5, success_threshold: 3, timeout: 30_000},
        id: :circuit_breaker_query_bus
      ),
      Supervisor.child_spec(
        {Shared.Infrastructure.Resilience.CircuitBreaker,
         name: :external_service, failure_threshold: 3, success_threshold: 2, timeout: 60_000},
        id: :circuit_breaker_external_service
      )
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  新しいサーキットブレーカーを動的に追加する
  """
  def add_circuit_breaker(name, opts \\ []) do
    child_spec = {
      Shared.Infrastructure.Resilience.CircuitBreaker,
      Keyword.merge([name: name], opts)
    }

    Supervisor.start_child(__MODULE__, child_spec)
  end

  @doc """
  サーキットブレーカーを削除する
  """
  def remove_circuit_breaker(name) do
    case Registry.lookup(Shared.CircuitBreakerRegistry, name) do
      [{pid, _}] ->
        Supervisor.terminate_child(__MODULE__, pid)
        Supervisor.delete_child(__MODULE__, pid)

      [] ->
        {:error, :not_found}
    end
  end
end

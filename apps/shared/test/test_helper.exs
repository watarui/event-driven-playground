ExUnit.start()

# アプリケーションを起動
{:ok, _} = Application.ensure_all_started(:shared)

# CircuitBreakerSupervisor が起動していない場合は手動で起動
case Process.whereis(Shared.Infrastructure.Resilience.CircuitBreakerSupervisor) do
  nil ->
    # CircuitBreakerSupervisorを手動で起動
    {:ok, _} = Shared.Infrastructure.Resilience.CircuitBreakerSupervisor.start_link([])

  _ ->
    :ok
end

# Ectoのサンドボックスモードを設定
Ecto.Adapters.SQL.Sandbox.mode(Shared.Infrastructure.EventStore.Repo, :manual)

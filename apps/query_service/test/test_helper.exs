ExUnit.start()

# アプリケーションを起動
{:ok, _} = Application.ensure_all_started(:shared)
{:ok, _} = Application.ensure_all_started(:query_service)

# Ectoのサンドボックスモードを設定
Ecto.Adapters.SQL.Sandbox.mode(QueryService.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Shared.Infrastructure.EventStore.Repo, :manual)

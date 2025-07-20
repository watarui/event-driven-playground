ExUnit.start()

# アプリケーションを起動
{:ok, _} = Application.ensure_all_started(:shared)
{:ok, _} = Application.ensure_all_started(:command_service)

# Ectoのサンドボックスモードを設定
Ecto.Adapters.SQL.Sandbox.mode(CommandService.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Shared.Infrastructure.EventStore.Repo, :manual)

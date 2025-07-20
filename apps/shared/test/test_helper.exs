ExUnit.start()

# アプリケーションを起動
{:ok, _} = Application.ensure_all_started(:shared)

# Ectoのサンドボックスモードを設定（共有モードに変更）
Ecto.Adapters.SQL.Sandbox.mode(Shared.Infrastructure.EventStore.Repo, :shared)

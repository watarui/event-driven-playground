ExUnit.start()

# Ectoのサンドボックスモードを設定
Ecto.Adapters.SQL.Sandbox.mode(Shared.Infrastructure.EventStore.Repo, :manual)

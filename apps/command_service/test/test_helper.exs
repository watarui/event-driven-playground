ExUnit.start()

# Ectoのサンドボックスモードを設定
Ecto.Adapters.SQL.Sandbox.mode(CommandService.Repo, :manual)

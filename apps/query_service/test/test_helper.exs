ExUnit.start()

# Ectoのサンドボックスモードを設定
Ecto.Adapters.SQL.Sandbox.mode(QueryService.Repo, :manual)

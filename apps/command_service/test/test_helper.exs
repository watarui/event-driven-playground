ExUnit.start()

# アプリケーションを起動
{:ok, _} = Application.ensure_all_started(:shared)
{:ok, _} = Application.ensure_all_started(:command_service)

# Firestore を使用しているため、Ecto のサンドボックスモードは不要

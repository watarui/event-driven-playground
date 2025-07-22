defmodule Shared.Health.Checks.DatabaseCheck do
  @moduledoc """
  Firestore 接続のヘルスチェック（FirestoreCheck のエイリアス）
  """

  alias Shared.Health.Checks.FirestoreCheck

  @doc """
  データベース（Firestore）の接続状態を確認
  """
  def check do
    FirestoreCheck.check()
  end
end
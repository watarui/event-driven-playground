defmodule Mix.Tasks.CleanupSagas do
  @moduledoc """
  古い SAGA をクリーンアップする Mix タスク

  使い方:
    mix cleanup_sagas
  """

  use Mix.Task

  import Ecto.Query, warn: false

  @shortdoc "古い SAGA をクリーンアップ"
  def run(_args) do
    # アプリケーションを起動
    Mix.Task.run("app.start")

    IO.puts("古い SAGA のクリーンアップを開始します...")

    # Repo を直接取得
    repo =
      Application.get_env(:shared, :ecto_repos, [])
      |> List.first()
      |> case do
        nil -> Shared.Infrastructure.Persistence.Repo
        r -> r
      end

    # アクティブな SAGA の数を確認
    count_sql = "SELECT COUNT(*) FROM event_store.sagas WHERE status IN ('started', 'processing')"

    case repo.query(count_sql, []) do
      {:ok, %{rows: [[count]]}} ->
        IO.puts("アクティブな SAGA の数: #{count}")

        if count > 0 do
          # 詳細を表示
          detail_sql = """
          SELECT id, saga_type, status, created_at 
          FROM event_store.sagas 
          WHERE status IN ('started', 'processing')
          ORDER BY created_at DESC
          LIMIT 10
          """

          case repo.query(detail_sql, []) do
            {:ok, %{rows: rows}} ->
              IO.puts("\n最新の10件:")

              Enum.each(rows, fn [id, saga_type, status, created_at] ->
                IO.puts(
                  "  ID: #{id}, Type: #{saga_type}, Status: #{status}, Created: #{created_at}"
                )
              end)
          end

          IO.puts("\nこれらの SAGA を削除しますか？ (y/n)")
          answer = IO.gets("") |> String.trim()

          if answer == "y" do
            # 削除実行
            delete_sql = "DELETE FROM event_store.sagas WHERE status IN ('started', 'processing')"

            case repo.query(delete_sql, []) do
              {:ok, %{num_rows: num_rows}} ->
                IO.puts("#{num_rows} 件の SAGA を削除しました")

              {:error, error} ->
                IO.puts("エラーが発生しました: #{inspect(error)}")
            end
          else
            IO.puts("キャンセルしました")
          end
        else
          IO.puts("削除する SAGA はありません")
        end

      {:error, error} ->
        IO.puts("SAGA の取得中にエラーが発生しました: #{inspect(error)}")
    end

    IO.puts("\n完了しました")
  end
end

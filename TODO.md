⏺ 現在の状況をまとめました。主な課題：

緊急度：高

- ~~command-service と query-service がポート設定エラーで起動失敗（PORT=8080）~~ ✅ 解決済み
  - Cloud Run のベストプラクティスに従い、EXPOSE ディレクティブを削除
  - terraform の不要な port 設定を削除
- Firestore データベースの本番環境構築が未完了
- ~~Ecto 依存関係がまだ shared/mix.exs に残っている~~ ✅ 削除済み
  - Ecto に依存する多数のファイルを /tmp/ecto_backup/ に移動
  - UUID ライブラリに移行（Ecto.UUID → elixir_uuid）

緊急度：中

- CI/CD パイプラインの動作確認が必要
- 環境変数と Secret Manager の設定確認
- Firebase Authentication の本番設定確認
- 新しく作成したモニタリング機能の動作確認

緊急度：低

- 不要な migration 関連の Cloud Run Jobs の削除
- ドキュメントの最終確認と更新

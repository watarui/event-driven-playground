# データベース戦略

## 概要

このプロジェクトでは、環境に応じて異なるデータベース戦略を採用しています：

- **開発環境**: マイクロサービスアーキテクチャの学習のため、サービスごとに独立したデータベースを使用
- **テスト・本番環境**: コスト最適化のため、単一データベース内でスキーマ分離を使用

## 環境別の構成

### 開発環境 (dev)

```
postgres-event-store (port: 5432)
├── event_driven_playground_event_store_dev

postgres-command (port: 5433)
├── event_driven_playground_command_dev

postgres-query (port: 5434)
├── event_driven_playground_query_dev
```

**利点**:
- 完全なサービス分離
- マイクロサービスパターンの実践的な学習
- サービス間の依存関係が明確

### テスト・本番環境 (test/prod)

```
postgres (port: 5432)
├── event_driven_playground_test / event_driven_playground_prod
    ├── schema: event_store
    ├── schema: command_service
    └── schema: query_service
```

**利点**:
- データベースコストの削減
- 運用管理の簡素化
- バックアップ・リストアの一元化

## 実装詳細

### スキーマ作成

`20250108000000_create_schemas.exs` マイグレーションが最初に実行され、必要なスキーマを作成します：

```elixir
if Mix.env() in [:test, :prod] do
  execute "CREATE SCHEMA IF NOT EXISTS event_store"
  execute "CREATE SCHEMA IF NOT EXISTS command_service"
  execute "CREATE SCHEMA IF NOT EXISTS query_service"
end
```

### Repo 設定

各 Repo は環境に応じて適切なスキーマを使用するよう設定されています：

```elixir
def init(_, config) do
  config = 
    if Mix.env() in [:test, :prod] do
      Keyword.put(config, :after_connect, {Ecto.Adapters.Postgres, :set_search_path, ["schema_name"]})
    else
      config
    end
  
  {:ok, config}
end
```

### データベース URL

`Shared.Config` モジュールが環境変数を管理：

- 開発環境: サービス固有の URL（例: `EVENT_STORE_DATABASE_URL`）
- テスト・本番環境: 共通の `DATABASE_URL`

## マイグレーション

各マイグレーションファイルは適切な `prefix` を指定：

- EventStore: `prefix: "event_store"`
- CommandService: `prefix: "command"`  
- QueryService: `prefix: "query"`

## この設計の理由

1. **学習価値の維持**: 開発環境では完全なマイクロサービス分離を体験
2. **実用的な運用**: 本番環境ではコストとメンテナンス性を重視
3. **柔軟性**: 将来的に本番環境でも分離が必要になった場合、設定変更で対応可能

## 注意事項

- CI/CD では単一データベースを前提とした設定
- 開発環境から本番環境へのデータ移行時はスキーママッピングが必要
- パフォーマンステストは本番環境と同じスキーマ構成で実施することを推奨
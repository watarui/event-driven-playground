# トラブルシューティングガイド

このガイドでは、Elixir CQRS/ES プロジェクトで発生する可能性のある一般的な問題とその解決方法を説明します。

## 📋 目次

- [起動時の問題](#起動時の問題)
- [データベース関連](#データベース関連)
- [サービス間通信](#サービス間通信)
- [イベントストア](#イベントストア)
- [プロジェクション](#プロジェクション)
- [GraphQL API](#graphql-api)
- [フロントエンド](#フロントエンド)
- [パフォーマンス](#パフォーマンス)
- [開発環境](#開発環境)

## 起動時の問題

### PostgreSQL が起動しない

**症状**: `pg_isready` が失敗する、または PostgreSQL コンテナが起動しない

**解決方法**:
```bash
# Docker の状態を確認
docker ps -a

# ログを確認
docker logs elixir-cqrs-postgres-event-store-1

# 既存のボリュームを削除して再作成
docker-compose down -v
docker-compose up -d postgres-event-store postgres-command postgres-query
```

### サービスが相互に接続できない

**症状**: `Postgrex.Protocol (#PID<...>) failed to connect` エラー

**解決方法**:
1. すべてのサービスが同じ Docker ネットワークにあることを確認:
   ```bash
   docker network inspect elixir-cqrs-network
   ```

2. 環境変数が正しく設定されていることを確認:
   ```bash
   docker-compose config
   ```

3. サービスの起動順序を確認（PostgreSQL → Command/Query Service → Client Service）

### ポートの競合

**症状**: `bind: address already in use` エラー

**解決方法**:
```bash
# 使用中のポートを確認
lsof -i :4000  # Client Service
lsof -i :5432  # PostgreSQL Event Store
lsof -i :5433  # PostgreSQL Command
lsof -i :5434  # PostgreSQL Query

# 競合するプロセスを停止するか、docker-compose.yml でポートを変更
```

## データベース関連

### マイグレーションエラー

**症状**: `(Postgrex.Error) ERROR 42P01 (undefined_table)` エラー

**解決方法**:
```bash
# マイグレーションを再実行
docker-compose exec command-service mix ecto.migrate
docker-compose exec query-service mix ecto.migrate
docker-compose exec shared mix ecto.migrate --repo Shared.Infrastructure.EventStore.Repo
```

### データベース接続エラー

**症状**: `connection not available and request was dropped from queue after XXXms`

**解決方法**:
1. データベースのプール設定を確認（`config/runtime.exs`）:
   ```elixir
   pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
   ```

2. PostgreSQL の最大接続数を増やす:
   ```sql
   ALTER SYSTEM SET max_connections = 200;
   SELECT pg_reload_conf();
   ```

### イベントストアのパフォーマンス問題

**症状**: イベントの読み込みが遅い

**解決方法**:
1. インデックスが正しく作成されていることを確認:
   ```sql
   -- pgweb または psql で実行
   \d events
   ```

2. イベントアーカイブを有効化（古いイベントをアーカイブ）:
   ```bash
   docker-compose exec shared mix archive.events --days-old 30
   ```

## サービス間通信

### RemoteCommandBus タイムアウト

**症状**: `GenServer #PID<...> terminating` with timeout error

**解決方法**:
1. Command Service が起動していることを確認:
   ```bash
   docker-compose ps command-service
   ```

2. タイムアウト値を調整（`apps/client_service/lib/client_service/infrastructure/remote_command_bus.ex`）:
   ```elixir
   @timeout 30_000  # 30秒に増やす
   ```

### イベントバスの配信エラー

**症状**: イベントが Query Service に届かない

**解決方法**:
1. Phoenix.PubSub が正しく設定されていることを確認
2. ログレベルを上げて詳細を確認:
   ```bash
   docker-compose exec query-service mix phx.server --logger-level debug
   ```

## イベントストア

### バージョン競合エラー

**症状**: `VersionConflictError: Expected version X but current version is Y`

**解決方法**:
1. 楽観的ロックの競合です。リトライロジックを実装:
   ```elixir
   def handle_command_with_retry(command, retries \\ 3) do
     case CommandBus.dispatch(command) do
       {:error, %VersionConflictError{}} when retries > 0 ->
         Process.sleep(100)
         handle_command_with_retry(command, retries - 1)
       result -> result
     end
   end
   ```

2. またはイベントストアのスナップショット機能を使用してパフォーマンスを改善

### スナップショットの問題

**症状**: スナップショットが作成されない、または読み込まれない

**解決方法**:
```bash
# スナップショットテーブルを確認
docker-compose exec postgres-event-store psql -U postgres -d event_store -c "SELECT * FROM snapshots ORDER BY created_at DESC LIMIT 10;"

# 手動でスナップショットを作成
docker-compose exec shared mix run -e "Shared.Infrastructure.EventStore.SnapshotStore.create_snapshot(aggregate_id, aggregate_state, version)"
```

## プロジェクション

### プロジェクションの不整合

**症状**: Query Service のデータが最新のイベントを反映していない

**解決方法**:
1. プロジェクションを再構築:
   ```bash
   # すべてのプロジェクションを再構築
   docker-compose exec query-service mix projection.rebuild --all

   # 特定のプロジェクションのみ再構築
   docker-compose exec query-service mix projection.rebuild --projection OrderProjection
   ```

2. イベントハンドラーのエラーを確認:
   ```bash
   docker-compose logs query-service | grep ERROR
   ```

### プロジェクション処理の遅延

**症状**: イベントの処理に時間がかかる

**解決方法**:
1. バッチ処理を有効化
2. 並列処理の設定を調整:
   ```elixir
   # apps/query_service/lib/query_service/infrastructure/projection_manager.ex
   concurrency: System.get_env("PROJECTION_CONCURRENCY", "4") |> String.to_integer()
   ```

## GraphQL API

### N+1 クエリ問題

**症状**: GraphQL クエリが大量のデータベースクエリを発生させる

**解決方法**:
1. Dataloader を正しく設定:
   ```elixir
   # apps/client_service/lib/client_service/graphql/dataloader.ex
   def data() do
     Dataloader.Ecto.new(QueryService.Repo, query: &query/2)
   end
   ```

2. クエリの最適化:
   ```elixir
   # プリロードを使用
   from(p in Product, preload: [:category])
   ```

### サブスクリプションが動作しない

**症状**: GraphQL サブスクリプションが更新を受信しない

**解決方法**:
1. WebSocket 接続を確認:
   ```javascript
   // frontend/lib/apollo-client.ts
   const wsUrl = process.env.NEXT_PUBLIC_WS_URL || 'ws://localhost:4000/socket/websocket'
   ```

2. Phoenix Channels の設定を確認
3. CORS 設定を確認

## フロントエンド

### Apollo Client キャッシュの問題

**症状**: UI が最新のデータを表示しない

**解決方法**:
```typescript
// キャッシュをクリア
client.clearStore()

// または特定のクエリを再取得
client.refetchQueries({
  include: ['GetProducts']
})
```

### WebSocket 接続エラー

**症状**: `WebSocket connection failed`

**解決方法**:
1. エンドポイントの設定を確認
2. ファイアウォール/プロキシ設定を確認
3. SSL/TLS 設定（本番環境）を確認

## パフォーマンス

### 高メモリ使用

**症状**: Elixir プロセスが大量のメモリを使用

**解決方法**:
1. プロセスの状態を確認:
   ```elixir
   # IEx セッション内で
   :observer.start()
   ```

2. メモリリークの可能性を調査:
   ```elixir
   Process.list() |> Enum.map(fn pid ->
     {:memory, memory} = Process.info(pid, :memory)
     {pid, memory}
   end) |> Enum.sort_by(&elem(&1, 1), :desc) |> Enum.take(10)
   ```

### 遅いクエリ

**症状**: API レスポンスが遅い

**解決方法**:
1. データベースクエリを最適化（EXPLAIN ANALYZE を使用）
2. インデックスを追加
3. キャッシュを実装:
   ```elixir
   # apps/query_service/lib/query_service/infrastructure/cache.ex
   Cache.get_or_compute(key, fn -> expensive_operation() end)
   ```

## 開発環境

### 依存関係のエラー

**症状**: `mix deps.get` が失敗する

**解決方法**:
```bash
# キャッシュをクリア
mix deps.clean --all
rm -rf _build deps
mix deps.get
mix deps.compile
```

### コンパイルエラー

**症状**: `cannot compile module`

**解決方法**:
```bash
# ビルドアーティファクトをクリーンアップ
mix clean
mix compile --force
```

### テストの失敗

**症状**: ランダムにテストが失敗する

**解決方法**:
1. テストを同期モードで実行:
   ```elixir
   # test/test_helper.exs
   ExUnit.configure(async: false)
   ```

2. データベースサンドボックスの設定を確認
3. テスト間の依存関係を排除

## ログとデバッグ

### ログレベルの調整

開発環境でより詳細なログを取得:
```elixir
# config/dev.exs
config :logger, level: :debug
```

### 特定のモジュールのデバッグ

```elixir
require Logger

# モジュール内で
Logger.debug("Current state: #{inspect(state)}")
Logger.info("Processing command: #{inspect(command)}")
```

### リモートデバッグ

実行中のノードに接続:
```bash
# ノード名を確認
docker-compose exec command-service elixir --name debug@127.0.0.1 --cookie secret -S mix phx.server

# 別のターミナルから接続
iex --name console@127.0.0.1 --cookie secret --remsh debug@127.0.0.1
```

## その他のリソース

- [開発ガイド](DEVELOPMENT.md) - 開発環境の詳細な設定
- [モニタリング](MONITORING.md) - メトリクスとトレーシングの詳細
- [運用ガイド](OPERATIONS.md) - 本番環境での運用方法

問題が解決しない場合は、以下の情報を含めて Issue を作成してください：
- エラーメッセージの全文
- 実行したコマンド
- 関連するログ（`docker-compose logs` の出力）
- 環境情報（OS、Docker バージョンなど）
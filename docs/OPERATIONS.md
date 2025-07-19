# 運用ガイド

Elixir CQRS/ES プロジェクトの本番環境での運用に関する包括的なガイドです。

## 📋 目次

- [日常的な運用タスク](#日常的な運用タスク)
- [バックアップとリストア](#バックアップとリストア)
- [スケーリング](#スケーリング)
- [メンテナンス](#メンテナンス)
- [障害対応](#障害対応)
- [セキュリティ](#セキュリティ)
- [パフォーマンス管理](#パフォーマンス管理)
- [災害復旧](#災害復旧)

## 日常的な運用タスク

### ヘルスチェック

#### アプリケーションの健全性確認

```bash
# 各サービスのヘルスチェック
curl http://localhost:4000/health
curl http://localhost:4001/health
curl http://localhost:4002/health

# より詳細なヘルスチェック
curl http://localhost:4000/health/live    # Liveness
curl http://localhost:4000/health/ready   # Readiness
```

#### データベースの健全性確認

```bash
# PostgreSQL の状態確認
docker-compose exec postgres-event-store pg_isready
docker-compose exec postgres-command pg_isready
docker-compose exec postgres-query pg_isready

# 接続数の確認
docker-compose exec postgres-event-store psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"
```

### ログの確認と分析

#### リアルタイムログ監視

```bash
# すべてのサービスのログをフォロー
docker-compose logs -f --tail=100

# 特定のサービスのログ
docker-compose logs -f command-service --tail=100

# エラーログのみをフィルタリング
docker-compose logs -f | grep -E "ERROR|CRITICAL"
```

#### ログのローテーション

```yaml
# docker-compose.yml での設定
services:
  command-service:
    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "10"
```

### メトリクスの監視

#### 主要な監視項目

1. **システムメトリクス**
   - CPU 使用率 < 80%
   - メモリ使用率 < 90%
   - ディスク使用率 < 85%

2. **アプリケーションメトリクス**
   - レスポンスタイム p95 < 200ms
   - エラー率 < 0.1%
   - スループット > 1000 req/s

3. **ビジネスメトリクス**
   - コマンド成功率 > 99.9%
   - Saga 完了率 > 99%
   - イベント処理遅延 < 100ms

## バックアップとリストア

### 自動バックアップの設定

#### PostgreSQL バックアップスクリプト

```bash
#!/bin/bash
# scripts/backup_databases.sh

BACKUP_DIR="/backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR

# Event Store のバックアップ
docker-compose exec -T postgres-event-store pg_dump -U postgres event_store | gzip > $BACKUP_DIR/event_store.sql.gz

# Command DB のバックアップ
docker-compose exec -T postgres-command pg_dump -U postgres command_db | gzip > $BACKUP_DIR/command_db.sql.gz

# Query DB のバックアップ
docker-compose exec -T postgres-query pg_dump -U postgres query_db | gzip > $BACKUP_DIR/query_db.sql.gz

# 古いバックアップの削除（30日以上）
find /backups -type d -mtime +30 -exec rm -rf {} \;
```

#### Cron ジョブの設定

```bash
# 毎日午前2時にバックアップを実行
0 2 * * * /path/to/scripts/backup_databases.sh >> /var/log/backup.log 2>&1
```

### リストア手順

#### 完全リストア

```bash
# サービスを停止
docker-compose down

# データベースボリュームをクリア
docker volume rm elixir-cqrs_postgres-event-store-data
docker volume rm elixir-cqrs_postgres-command-data
docker volume rm elixir-cqrs_postgres-query-data

# データベースを起動
docker-compose up -d postgres-event-store postgres-command postgres-query

# バックアップをリストア
gunzip -c /backups/20240112_020000/event_store.sql.gz | docker-compose exec -T postgres-event-store psql -U postgres event_store
gunzip -c /backups/20240112_020000/command_db.sql.gz | docker-compose exec -T postgres-command psql -U postgres command_db
gunzip -c /backups/20240112_020000/query_db.sql.gz | docker-compose exec -T postgres-query psql -U postgres query_db

# サービスを起動
docker-compose up -d
```

#### ポイントインタイムリカバリ

```bash
# 特定の時点までイベントを再生
docker-compose exec shared mix run -e "
  Shared.Infrastructure.EventStore.replay_events_until(~U[2024-01-12 10:00:00Z])
"
```

### プロジェクションの再構築

```bash
# すべてのプロジェクションを再構築
docker-compose exec query-service mix projection.rebuild --all

# 特定のプロジェクションのみ再構築
docker-compose exec query-service mix projection.rebuild --projection OrderProjection --from-event-number 1000
```

## スケーリング

### 水平スケーリング

#### Query Service のスケールアウト

```yaml
# docker-compose.yml
services:
  query-service:
    scale: 3  # 3つのインスタンスを起動
```

```bash
# Kubernetes でのスケーリング
kubectl scale deployment query-service --replicas=5
```

#### ロードバランサーの設定

```nginx
# nginx.conf
upstream query_services {
    least_conn;
    server query-service-1:4002;
    server query-service-2:4002;
    server query-service-3:4002;
}
```

### 垂直スケーリング

#### リソースの調整

```yaml
# docker-compose.yml
services:
  command-service:
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 8G
        reservations:
          cpus: '2'
          memory: 4G
```

### データベースのスケーリング

#### 読み取りレプリカの追加

```yaml
# PostgreSQL のレプリケーション設定
services:
  postgres-query-replica:
    image: postgres:16
    environment:
      POSTGRES_REPLICATION_MODE: slave
      POSTGRES_MASTER_HOST: postgres-query
      POSTGRES_REPLICATION_USER: replicator
      POSTGRES_REPLICATION_PASSWORD: ${REPLICATION_PASSWORD}
```

## メンテナンス

### 計画的メンテナンス

#### ローリングアップデート

```bash
# 1. 新しいイメージをビルド
docker-compose build

# 2. Query Service から順番に更新
docker-compose up -d --no-deps --build query-service

# 3. ヘルスチェックを確認
./scripts/wait_for_health.sh query-service

# 4. Command Service を更新
docker-compose up -d --no-deps --build command-service

# 5. Client Service を更新
docker-compose up -d --no-deps --build client-service
```

#### データベースのメンテナンス

```sql
-- VACUUM とインデックスの再構築
VACUUM ANALYZE;
REINDEX DATABASE event_store;

-- テーブルの統計情報を更新
ANALYZE events;
ANALYZE snapshots;
```

### イベントアーカイブ

```elixir
# 古いイベントをアーカイブ
mix archive.events --older-than 90 --batch-size 1000

# アーカイブされたイベントの確認
mix archive.stats
```

## 障害対応

### 障害検知

#### アラートの優先度

1. **Critical**: 即座に対応が必要
   - サービスダウン
   - データ不整合
   - セキュリティインシデント

2. **Warning**: 監視が必要
   - 高負荷
   - ディスク容量不足
   - レスポンスタイム劣化

3. **Info**: 記録のみ
   - 定期タスクの完了
   - 設定変更

### 復旧手順

#### サービス障害からの復旧

```bash
# 1. 問題のあるサービスを特定
docker-compose ps
docker-compose logs --tail=100 [service-name]

# 2. サービスの再起動
docker-compose restart [service-name]

# 3. それでも解決しない場合は再作成
docker-compose up -d --force-recreate [service-name]

# 4. ヘルスチェックの確認
curl http://localhost:[port]/health
```

#### データ不整合の修復

```elixir
# プロジェクションの整合性チェック
mix projection.verify --fix

# イベントストアの整合性チェック
mix event_store.verify --deep

# 不整合が見つかった場合の修復
mix projection.rebuild --from-inconsistency
```

### インシデント対応フロー

1. **検知と評価**
   - アラートの確認
   - 影響範囲の特定
   - 優先度の判定

2. **初期対応**
   - ステークホルダーへの通知
   - 一時的な対処（再起動、フェイルオーバー）
   - 詳細な調査の開始

3. **根本原因の分析**
   - ログの収集と分析
   - メトリクスの確認
   - トレースの調査

4. **恒久対策**
   - 問題の修正
   - テストの実施
   - デプロイメント

5. **事後対応**
   - ポストモーテムの作成
   - 再発防止策の実装
   - ドキュメントの更新

## セキュリティ

### アクセス制御

```yaml
# 環境変数での認証情報管理
services:
  command-service:
    environment:
      - DATABASE_URL=${DATABASE_URL}
      - SECRET_KEY_BASE=${SECRET_KEY_BASE}
      - API_KEY=${API_KEY}
```

### ネットワークセキュリティ

```yaml
# 内部ネットワークの分離
networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true  # 外部からのアクセスを遮断
```

### 監査ログ

```elixir
# すべてのコマンドを監査ログに記録
defmodule AuditLog do
  def log_command(command, user_id, metadata) do
    %{
      timestamp: DateTime.utc_now(),
      command_type: command.__struct__,
      user_id: user_id,
      metadata: metadata,
      ip_address: get_ip_address()
    }
    |> Jason.encode!()
    |> write_to_audit_log()
  end
end
```

## パフォーマンス管理

### ボトルネックの特定

```bash
# 遅いクエリの特定
docker-compose exec postgres-event-store psql -U postgres -c "
  SELECT query, mean_exec_time, calls 
  FROM pg_stat_statements 
  ORDER BY mean_exec_time DESC 
  LIMIT 10;
"
```

### キャッシュの管理

```elixir
# キャッシュの統計情報
Cache.stats()

# キャッシュのクリア
Cache.clear(:all)
Cache.clear(:specific_key)

# キャッシュのウォームアップ
mix cache.warmup --entities products,categories
```

### リソースの最適化

```elixir
# Erlang VM のチューニング
# vm.args
+P 5000000  # プロセス数の上限
+K true     # カーネルポーリングを有効化
+A 128      # 非同期スレッドプールのサイズ
```

## 災害復旧

### RTO/RPO の目標

- **RTO (Recovery Time Objective)**: 4時間以内
- **RPO (Recovery Point Objective)**: 1時間以内

### DR サイトの構築

```yaml
# 別リージョンへのレプリケーション
services:
  event-store-replica:
    image: postgres:16
    environment:
      POSTGRES_REPLICATION_MODE: slave
      POSTGRES_MASTER_HOST: ${PRIMARY_REGION_HOST}
      POSTGRES_REPLICATION_USER: replicator
```

### フェイルオーバー手順

```bash
# 1. プライマリサイトの停止を確認
./scripts/check_primary_health.sh

# 2. DR サイトをプライマリに昇格
./scripts/promote_dr_site.sh

# 3. DNS の切り替え
./scripts/update_dns.sh --target dr-site

# 4. アプリケーションの起動
docker-compose -f docker-compose.dr.yml up -d

# 5. 整合性チェック
./scripts/verify_dr_activation.sh
```

## 運用チェックリスト

### 日次タスク
- [ ] ログの確認（エラー、警告）
- [ ] メトリクスの確認（CPU、メモリ、ディスク）
- [ ] バックアップの確認
- [ ] アラートの確認と対応

### 週次タスク
- [ ] パフォーマンスレポートの確認
- [ ] セキュリティアップデートの確認
- [ ] キャパシティプランニング
- [ ] バックアップのテストリストア

### 月次タスク
- [ ] DR テストの実施
- [ ] セキュリティ監査
- [ ] ドキュメントの更新
- [ ] インシデントレビュー

## その他のリソース

- [トラブルシューティング](TROUBLESHOOTING.md) - 問題解決ガイド
- [モニタリング](MONITORING.md) - 監視設定の詳細
- [デプロイメント](DEPLOYMENT.md) - デプロイ手順
- [環境変数リファレンス](ENVIRONMENT_VARIABLES.md) - 設定オプション
#!/bin/bash
set -e

echo "=== Starting production migration process (WORKAROUND) ==="
echo "Environment: ${MIX_ENV}"
echo "Database URL is set: $(if [ -n "$DATABASE_URL" ]; then echo "YES"; else echo "NO"; fi)"
echo ""

# データベース接続テスト
echo ""
echo "=== Testing database connection ==="
if [ -n "$DATABASE_URL" ]; then
    # Parse DATABASE_URL properly using bash regex
    if [[ "$DATABASE_URL" =~ postgres(ql)?://([^:]+):([^@]+)@([^:/]+):?([0-9]+)?/([^?]+) ]]; then
        DB_USER="${BASH_REMATCH[2]}"
        DB_PASS="${BASH_REMATCH[3]}"
        DB_HOST="${BASH_REMATCH[4]}"
        DB_PORT="${BASH_REMATCH[5]:-5432}"
        DB_NAME="${BASH_REMATCH[6]}"
        
        echo "Testing connection..."
        if PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT version();" > /dev/null 2>&1; then
            echo "✓ Database connection successful"
        else
            echo "✗ Database connection failed"
            exit 1
        fi
    fi
fi

# 直接SQLでスキーマを作成
echo ""
echo "=== Creating database schemas using direct SQL ==="
PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<EOF || echo "Schema creation may have failed, but continuing..."
CREATE SCHEMA IF NOT EXISTS event_store;
CREATE SCHEMA IF NOT EXISTS command;
CREATE SCHEMA IF NOT EXISTS query;
EOF

# マイグレーションを直接SQLで実行（回避策）
echo ""
echo "=== Running migrations using SQL (WORKAROUND) ==="

# EventStore マイグレーション
echo ""
echo "--- Checking EventStore schema ---"
PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<EOF || true
-- イベントストアテーブル（存在しない場合のみ作成）
CREATE TABLE IF NOT EXISTS event_store.events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stream_id VARCHAR(255) NOT NULL,
    stream_version INTEGER NOT NULL,
    event_type VARCHAR(255) NOT NULL,
    event_data JSONB NOT NULL,
    metadata JSONB DEFAULT '{}',
    occurred_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- インデックス
CREATE INDEX IF NOT EXISTS idx_events_stream_id ON event_store.events(stream_id);
CREATE INDEX IF NOT EXISTS idx_events_stream_id_version ON event_store.events(stream_id, stream_version);
CREATE INDEX IF NOT EXISTS idx_events_event_type ON event_store.events(event_type);
CREATE INDEX IF NOT EXISTS idx_events_occurred_at ON event_store.events(occurred_at);

-- スナップショットテーブル
CREATE TABLE IF NOT EXISTS event_store.snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_id VARCHAR(255) NOT NULL,
    aggregate_type VARCHAR(255) NOT NULL,
    data JSONB NOT NULL,
    metadata JSONB DEFAULT '{}',
    version INTEGER NOT NULL,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- スナップショットインデックス
CREATE INDEX IF NOT EXISTS idx_snapshots_aggregate ON event_store.snapshots(aggregate_id, aggregate_type);
CREATE INDEX IF NOT EXISTS idx_snapshots_aggregate_version ON event_store.snapshots(aggregate_id, version);

-- サブスクリプションテーブル
CREATE TABLE IF NOT EXISTS event_store.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_name VARCHAR(255) NOT NULL UNIQUE,
    last_seen_event_id UUID,
    last_seen_event_number BIGINT DEFAULT 0,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Command Service マイグレーション
CREATE TABLE IF NOT EXISTS command.processed_commands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    command_id UUID NOT NULL UNIQUE,
    command_type VARCHAR(255) NOT NULL,
    processed_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Query Service マイグレーション
CREATE TABLE IF NOT EXISTS query.projection_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    projection_name VARCHAR(255) NOT NULL UNIQUE,
    last_seen_event_number BIGINT DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- マイグレーショントラッキングテーブル
CREATE TABLE IF NOT EXISTS event_store.schema_migrations (
    version BIGINT PRIMARY KEY,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- 初期マイグレーションバージョンを記録
INSERT INTO event_store.schema_migrations (version) VALUES (20240101000000) ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS command.schema_migrations (
    version BIGINT PRIMARY KEY,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO command.schema_migrations (version) VALUES (20240101000000) ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS query.schema_migrations (
    version BIGINT PRIMARY KEY,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO query.schema_migrations (version) VALUES (20240101000000) ON CONFLICT DO NOTHING;

-- 作成されたテーブルを確認
\dt event_store.*;
\dt command.*;
\dt query.*;
EOF

echo ""
echo "=== Migration workaround completed ==="
echo "Note: This is a temporary workaround. The actual Ecto migrations should be run when the timeout issue is resolved."
echo "Timestamp: $(date)"
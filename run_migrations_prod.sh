#!/bin/sh
set -e

echo "=== Starting production migration process ==="
echo "Environment: ${MIX_ENV}"
echo "Database URL is set: $(if [ -n "$DATABASE_URL" ]; then echo "YES"; else echo "NO"; fi)"

# デバッグ情報
echo ""
echo "=== Environment Information ==="
echo "Current directory: $(pwd)"
echo "Hostname: $(hostname)"
echo "Date: $(date)"

# データベース接続テスト
echo ""
echo "=== Testing database connection ==="
if [ -n "$DATABASE_URL" ]; then
    # Extract connection details from DATABASE_URL
    DB_HOST=$(echo $DATABASE_URL | sed -E 's/.*@([^:\/]+).*/\1/')
    DB_PORT=$(echo $DATABASE_URL | sed -E 's/.*:([0-9]+)\/.*/\1/' || echo "5432")
    DB_NAME=$(echo $DATABASE_URL | sed -E 's/.*\/([^?]+).*/\1/')
    
    echo "Database host: $DB_HOST"
    echo "Database port: $DB_PORT"
    echo "Database name: $DB_NAME"
    
    # Test connection using psql
    echo "Testing connection..."
    if PGPASSWORD=$DATABASE_URL psql "$DATABASE_URL" -c "SELECT version();" > /dev/null 2>&1; then
        echo "✓ Database connection successful"
    else
        echo "✗ Database connection failed"
        echo "Attempting detailed connection test..."
        PGPASSWORD=$DATABASE_URL psql "$DATABASE_URL" -c "SELECT 1;" || true
    fi
else
    echo "ERROR: DATABASE_URL not set"
    exit 1
fi

# アプリケーション構造の確認
echo ""
echo "=== Application structure ==="
ls -la /app/apps/ || echo "Apps directory not found"

# 本番環境では単一DBを使用するため、スキーマを作成
echo ""
echo "=== Creating database schemas (if not exists) ==="
cd /app

# Mix環境でスキーマを作成
echo "Creating schemas using Mix task..."
mix db.create_schemas || {
    echo "Mix task failed, attempting direct SQL..."
    # フォールバック: 直接SQLでスキーマを作成
    PGPASSWORD=$DATABASE_URL psql "$DATABASE_URL" <<EOF || true
CREATE SCHEMA IF NOT EXISTS event_store;
CREATE SCHEMA IF NOT EXISTS command;
CREATE SCHEMA IF NOT EXISTS query;
EOF
}

# マイグレーションの実行
echo ""
echo "=== Running migrations ==="

# Shared (EventStore) のマイグレーション
echo ""
echo "--- Running Shared (EventStore) migrations ---"
cd /app/apps/shared
echo "Migration files:"
ls -la priv/repo/migrations/ 2>/dev/null || echo "No migrations directory"

echo "Running migration..."
mix ecto.migrate -r Shared.Infrastructure.EventStore.Repo --log-migrations-sql || {
    echo "ERROR: Shared migration failed"
    echo "Attempting to get more details..."
    mix ecto.migrations -r Shared.Infrastructure.EventStore.Repo || true
    exit 1
}

# CommandService のマイグレーション
echo ""
echo "--- Running CommandService migrations ---"
cd /app/apps/command_service
echo "Migration files:"
ls -la priv/repo/migrations/ 2>/dev/null || echo "No migrations directory"

echo "Running migration..."
mix ecto.migrate -r CommandService.Repo --log-migrations-sql || {
    echo "ERROR: CommandService migration failed"
    echo "Attempting to get more details..."
    mix ecto.migrations -r CommandService.Repo || true
    exit 1
}

# QueryService のマイグレーション
echo ""
echo "--- Running QueryService migrations ---"
cd /app/apps/query_service
echo "Migration files:"
ls -la priv/repo/migrations/ 2>/dev/null || echo "No migrations directory"

echo "Running migration..."
mix ecto.migrate -r QueryService.Repo --log-migrations-sql || {
    echo "ERROR: QueryService migration failed"
    echo "Attempting to get more details..."
    mix ecto.migrations -r QueryService.Repo || true
    exit 1
}

# 最終確認
echo ""
echo "=== Migration Summary ==="
echo "Checking final migration status..."

cd /app
echo ""
echo "Shared migrations:"
mix ecto.migrations -r Shared.Infrastructure.EventStore.Repo || echo "Failed to get status"

echo ""
echo "CommandService migrations:"
mix ecto.migrations -r CommandService.Repo || echo "Failed to get status"

echo ""
echo "QueryService migrations:"
mix ecto.migrations -r QueryService.Repo || echo "Failed to get status"

echo ""
echo "=== All migrations completed successfully! ==="
echo "Timestamp: $(date)"
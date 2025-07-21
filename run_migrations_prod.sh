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

# DNS デバッグ
echo ""
echo "=== DNS Configuration ==="
echo "Resolv.conf contents:"
cat /etc/resolv.conf || echo "Unable to read /etc/resolv.conf"
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
        
        echo "Parsed connection details:"
        echo "  Host: $DB_HOST"
        echo "  Port: $DB_PORT"
        echo "  Database: $DB_NAME"
        echo "  User: $DB_USER"
        
        # DNS 解決テスト
        echo ""
        echo "Testing DNS resolution for $DB_HOST..."
        if command -v nslookup >/dev/null 2>&1; then
            nslookup "$DB_HOST" || echo "nslookup failed"
        elif command -v dig >/dev/null 2>&1; then
            dig "$DB_HOST" +short || echo "dig failed"
        elif command -v getent >/dev/null 2>&1; then
            getent hosts "$DB_HOST" || echo "getent failed"
        else
            echo "No DNS tools available, trying ping..."
            ping -c 1 "$DB_HOST" || echo "ping failed"
        fi
        
        echo ""
        echo "Testing connection..."
        if PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT version();" > /dev/null 2>&1; then
            echo "✓ Database connection successful"
        else
            echo "✗ Database connection failed"
            echo "Attempting detailed connection test..."
            PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" 2>&1 || true
        fi
    else
        echo "✗ Failed to parse DATABASE_URL"
        echo "URL format should be: postgresql://user:pass@host:port/dbname"
        exit 1
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
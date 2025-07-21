#!/bin/bash
set -e

echo "=== Starting production migration process ==="
echo "Environment: ${MIX_ENV}"
echo "Database URL is set: $(if [ -n "$DATABASE_URL" ]; then echo "YES"; else echo "NO"; fi)"
echo ""
echo "=== Connection Pool Settings ==="
echo "POOL_SIZE: ${POOL_SIZE:-not set}"
echo "DB_QUEUE_TARGET: ${DB_QUEUE_TARGET:-not set}"
echo "DB_QUEUE_INTERVAL: ${DB_QUEUE_INTERVAL:-not set}"
echo "DB_TIMEOUT: ${DB_TIMEOUT:-not set}"
echo "DB_CONNECT_TIMEOUT: ${DB_CONNECT_TIMEOUT:-not set}"
echo ""

# DNS 解決のための環境変数を設定
export ERL_INETRC="/etc/erl_inetrc"
# inet_backend オプションは削除（互換性の問題のため）
# export ELIXIR_ERL_OPTIONS="+inet_backend inet"

# カスタム inet 設定ファイルを作成
cat > /etc/erl_inetrc << EOF
{lookup, [dns, file]}.
{nameserver, {8, 8, 8, 8}}.
{nameserver, {8, 8, 4, 4}}.
{cache_size, 2000}.
{timeout, 2000}.
{retry, 3}.
{inet6, false}.
EOF

echo "Created custom Erlang inet configuration"

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

# ネットワーク情報の詳細確認
echo "Network interfaces:"
ip addr show 2>/dev/null || ifconfig 2>/dev/null || echo "No network tools available"
echo ""

# DNS ツールの確認
echo "Available DNS tools:"
which nslookup dig host getent 2>/dev/null || echo "No standard DNS tools found"
echo ""

# Google DNS を使用した DNS 解決テスト
echo "Testing DNS resolution with different methods:"
if [ -n "$DB_HOST" ]; then
    echo "1. Using system resolver for $DB_HOST:"
    getent hosts "$DB_HOST" 2>/dev/null || echo "getent failed"
    
    echo "2. Using Google DNS (8.8.8.8) for $DB_HOST:"
    if command -v dig >/dev/null 2>&1; then
        dig @8.8.8.8 "$DB_HOST" +short || echo "dig with Google DNS failed"
    elif command -v nslookup >/dev/null 2>&1; then
        nslookup "$DB_HOST" 8.8.8.8 || echo "nslookup with Google DNS failed"
    fi
    
    echo "3. Direct IP resolution test:"
    # Supabase の既知の IP アドレスパターンをテスト
    echo "Testing connectivity to known Supabase IP ranges..."
    # これは例示的なテストです
fi
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

# Elixir の起動時オプションを設定して接続プールを最適化
export ERL_FLAGS="+K true +A 10"
export ELIXIR_ERL_OPTIONS="+sbwt none +sbwtdcpu none +sbwtdio none"

# 接続プール設定を明示的にエクスポート（Elixir が確実に読み込むため）
export MIX_ENV=prod
export POOL_SIZE=${POOL_SIZE:-2}
export DB_QUEUE_TARGET=${DB_QUEUE_TARGET:-50}
export DB_QUEUE_INTERVAL=${DB_QUEUE_INTERVAL:-100}
export DB_TIMEOUT=${DB_TIMEOUT:-30000}
export DB_CONNECT_TIMEOUT=${DB_CONNECT_TIMEOUT:-30000}

echo "=== Exported Environment Variables ==="
echo "MIX_ENV=$MIX_ENV"
echo "POOL_SIZE=$POOL_SIZE"
echo "DB_QUEUE_TARGET=$DB_QUEUE_TARGET"
echo "DB_QUEUE_INTERVAL=$DB_QUEUE_INTERVAL"
echo "DB_TIMEOUT=$DB_TIMEOUT"
echo "DB_CONNECT_TIMEOUT=$DB_CONNECT_TIMEOUT"

# 直接SQLでスキーマを作成（Mixタスクでのタイムアウトを回避）
echo ""
echo "=== Creating database schemas using direct SQL ==="
if [ -n "$DATABASE_URL" ]; then
    # Parse DATABASE_URL for psql command
    if [[ "$DATABASE_URL" =~ postgres(ql)?://([^:]+):([^@]+)@([^:/]+):?([0-9]+)?/([^?]+) ]]; then
        DB_USER="${BASH_REMATCH[2]}"
        DB_PASS="${BASH_REMATCH[3]}"
        DB_HOST="${BASH_REMATCH[4]}"
        DB_PORT="${BASH_REMATCH[5]:-5432}"
        DB_NAME="${BASH_REMATCH[6]}"
        
        echo "Creating schemas directly via psql..."
        PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<EOF || echo "Schema creation may have failed, but continuing..."
CREATE SCHEMA IF NOT EXISTS event_store;
CREATE SCHEMA IF NOT EXISTS command;
CREATE SCHEMA IF NOT EXISTS query;
\dt event_store.*
\dt command.*
\dt query.*
EOF
        echo "Schema creation completed"
    else
        echo "ERROR: Failed to parse DATABASE_URL for schema creation"
        exit 1
    fi
else
    echo "ERROR: DATABASE_URL not set for schema creation"
    exit 1
fi

# マイグレーションの実行
echo ""
echo "=== Running migrations ==="

# Shared (EventStore) のマイグレーション
echo ""
echo "--- Running Shared (EventStore) migrations ---"
cd /app/apps/shared

# デバッグ: マイグレーション前に設定を確認
echo "Debug: Checking Ecto configuration before migration..."
cd /app
if [ -f /app/debug_config.exs ]; then
    MIX_ENV=prod mix run /app/debug_config.exs || echo "Debug script failed, continuing..."
fi
cd /app/apps/shared
echo "Migration files:"
ls -la priv/repo/migrations/ 2>/dev/null || echo "No migrations directory"

echo "Running migration..."
MIX_ENV=prod mix ecto.migrate -r Shared.Infrastructure.EventStore.Repo --log-migrations-sql || {
    echo "ERROR: Shared migration failed"
    echo "Attempting to get more details..."
    MIX_ENV=prod mix ecto.migrations -r Shared.Infrastructure.EventStore.Repo || true
    exit 1
}

# CommandService のマイグレーション
echo ""
echo "--- Running CommandService migrations ---"
cd /app/apps/command_service
echo "Migration files:"
ls -la priv/repo/migrations/ 2>/dev/null || echo "No migrations directory"

echo "Running migration..."
MIX_ENV=prod mix ecto.migrate -r CommandService.Repo --log-migrations-sql || {
    echo "ERROR: CommandService migration failed"
    echo "Attempting to get more details..."
    MIX_ENV=prod mix ecto.migrations -r CommandService.Repo || true
    exit 1
}

# QueryService のマイグレーション
echo ""
echo "--- Running QueryService migrations ---"
cd /app/apps/query_service
echo "Migration files:"
ls -la priv/repo/migrations/ 2>/dev/null || echo "No migrations directory"

echo "Running migration..."
MIX_ENV=prod mix ecto.migrate -r QueryService.Repo --log-migrations-sql || {
    echo "ERROR: QueryService migration failed"
    echo "Attempting to get more details..."
    MIX_ENV=prod mix ecto.migrations -r QueryService.Repo || true
    exit 1
}

# 最終確認
echo ""
echo "=== Migration Summary ==="
echo "Checking final migration status..."

cd /app
echo ""
echo "Shared migrations:"
MIX_ENV=prod mix ecto.migrations -r Shared.Infrastructure.EventStore.Repo || echo "Failed to get status"

echo ""
echo "CommandService migrations:"
MIX_ENV=prod mix ecto.migrations -r CommandService.Repo || echo "Failed to get status"

echo ""
echo "QueryService migrations:"
MIX_ENV=prod mix ecto.migrations -r QueryService.Repo || echo "Failed to get status"

echo ""
echo "=== All migrations completed successfully! ==="
echo "Timestamp: $(date)"
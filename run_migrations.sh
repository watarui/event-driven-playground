#!/bin/sh
set -e

echo "=== Starting migration process ==="
echo "Environment: ${MIX_ENV}"
echo "Database URL is set: $(if [ -n "$DATABASE_URL" ]; then echo "YES"; else echo "NO"; fi)"

# デバッグ情報を表示
echo "Current directory: $(pwd)"
echo "App structure:"
ls -la /app/apps/

# event_store (shared) マイグレーション
# shared のマイグレーションにはスキーマ作成が含まれるため、最初に実行する必要がある
echo ""
echo "=== Running shared migrations (including schema creation) ==="
cd /app/apps/shared
echo "Migration files in shared:"
ls -la priv/repo/migrations/ || echo "No migrations directory found"
mix ecto.migrate -r Shared.Infrastructure.EventStore.Repo || { echo "Shared migration failed"; exit 1; }

# command_service マイグレーション
echo ""
echo "=== Running command_service migrations ==="
cd /app/apps/command_service
echo "Migration files in command_service:"
ls -la priv/repo/migrations/ || echo "No migrations directory found"
mix ecto.migrate -r CommandService.Repo || { echo "Command service migration failed"; exit 1; }

# query_service マイグレーション
echo ""
echo "=== Running query_service migrations ==="
cd /app/apps/query_service
echo "Migration files in query_service:"
ls -la priv/repo/migrations/ || echo "No migrations directory found"
mix ecto.migrate -r QueryService.Repo || { echo "Query service migration failed"; exit 1; }

echo ""
echo "=== All migrations completed successfully! ==="
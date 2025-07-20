#!/bin/sh
set -e

echo "Running migrations..."

# event_store (shared) マイグレーション
# shared のマイグレーションにはスキーマ作成が含まれるため、最初に実行する必要がある
echo "Running shared migrations (including schema creation)..."
cd /app/apps/shared
mix ecto.migrate

# command_service マイグレーション
echo "Running command_service migrations..."
cd /app/apps/command_service
mix ecto.migrate

# query_service マイグレーション
echo "Running query_service migrations..."
cd /app/apps/query_service
mix ecto.migrate

echo "All migrations completed successfully!"
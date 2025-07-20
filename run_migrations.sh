#!/bin/sh
set -e

echo "Running migrations..."

# event_store (shared) マイグレーション
echo "Running shared migrations..."
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
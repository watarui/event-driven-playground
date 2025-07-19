#!/bin/bash

# ==============================================================================
# 初回セットアップスクリプト
# Docker起動、データベース作成、マイグレーション実行
# ==============================================================================

set -e

# 共通ライブラリの読み込み
source "$(dirname "$0")/lib/common.sh"

# ログファイルの準備
ensure_log_dir
SETUP_LOG="$LOG_DIR/setup_$(date +%Y%m%d_%H%M%S).log"
info "ログファイル: $SETUP_LOG"

section "🚀 Event Driven Playground 初回セットアップ"

# ==============================================================================
# Docker チェックと起動
# ==============================================================================

info "Docker の状態を確認しています..."

if ! is_docker_running; then
    error "Docker が起動していません。Docker Desktop を起動してください。"
    exit 1
fi

if ! are_containers_running; then
    error "Docker コンテナが起動していません"
    log ""
    log "以下のコマンドで Docker を起動してください:"
    log "  ${CYAN}docker compose up -d${NC}"
    log ""
    log "その後、もう一度このスクリプトを実行してください"
    exit 1
fi

success "Docker コンテナが起動しています"

# PostgreSQL の接続確認
info "PostgreSQL への接続を確認しています..."
for port in 5432 5433 5434; do
    if ! check_postgres $port; then
        error "PostgreSQL (port $port) に接続できません"
        log "Docker コンテナが正常に起動しているか確認してください"
        exit 1
    fi
done
success "すべての PostgreSQL インスタンスに接続できました"

# ==============================================================================
# 依存関係の取得
# ==============================================================================

section "📦 依存関係の取得"

cd "$PROJECT_ROOT"
info "mix deps.get を実行しています..."
if mix deps.get >> "$SETUP_LOG" 2>&1; then
    success "依存関係の取得が完了しました"
else
    error "依存関係の取得に失敗しました。詳細は $SETUP_LOG を確認してください"
    exit 1
fi

# ==============================================================================
# データベースセットアップ
# ==============================================================================

section "🗄️  データベースセットアップ"

# Event Store (Shared)
info "Event Store のセットアップを開始します..."
cd "$PROJECT_ROOT/apps/shared"

# データベース作成
info "Event Store データベースを作成しています..."
if mix ecto.create --repo Shared.Infrastructure.EventStore.Repo >> "$SETUP_LOG" 2>&1; then
    success "Event Store データベースを作成しました"
else
    # すでに存在する場合もあるので、エラーを確認
    if database_exists "event_driven_playground_event_dev" 5432; then
        info "Event Store データベースは既に存在します"
    else
        error "Event Store データベースの作成に失敗しました。詳細は $SETUP_LOG を確認してください"
        exit 1
    fi
fi

# スキーマ作成
psql -h localhost -p 5432 -U postgres -d event_driven_playground_event_dev \
    -c "CREATE SCHEMA IF NOT EXISTS event_store;" > /dev/null 2>&1
success "Event Store スキーマを作成しました"

# マイグレーション
info "Event Store のマイグレーションを実行しています..."
if mix ecto.migrate --repo Shared.Infrastructure.EventStore.Repo >> "$SETUP_LOG" 2>&1; then
    success "Event Store のマイグレーションが完了しました"
else
    error "Event Store のマイグレーションに失敗しました。詳細は $SETUP_LOG を確認してください"
    exit 1
fi

# Command Service
info "Command Service のセットアップを開始します..."
cd "$PROJECT_ROOT/apps/command_service"

info "Command Service データベースを作成しています..."
if mix ecto.create >> "$SETUP_LOG" 2>&1; then
    success "Command Service データベースを作成しました"
else
    if database_exists "event_driven_playground_command_dev" 5433; then
        info "Command Service データベースは既に存在します"
    else
        error "Command Service データベースの作成に失敗しました。詳細は $SETUP_LOG を確認してください"
        exit 1
    fi
fi

psql -h localhost -p 5433 -U postgres -d event_driven_playground_command_dev \
    -c "CREATE SCHEMA IF NOT EXISTS command;" > /dev/null 2>&1
success "Command Service スキーマを作成しました"

if mix ecto.migrate >> "$SETUP_LOG" 2>&1; then
    success "Command Service のマイグレーションが完了しました"
else
    error "Command Service のマイグレーションに失敗しました。詳細は $SETUP_LOG を確認してください"
    exit 1
fi

# Query Service
info "Query Service のセットアップを開始します..."
cd "$PROJECT_ROOT/apps/query_service"

info "Query Service データベースを作成しています..."
if mix ecto.create >> "$SETUP_LOG" 2>&1; then
    success "Query Service データベースを作成しました"
else
    if database_exists "event_driven_playground_query_dev" 5434; then
        info "Query Service データベースは既に存在します"
    else
        error "Query Service データベースの作成に失敗しました。詳細は $SETUP_LOG を確認してください"
        exit 1
    fi
fi

psql -h localhost -p 5434 -U postgres -d event_driven_playground_query_dev \
    -c "CREATE SCHEMA IF NOT EXISTS query;" > /dev/null 2>&1
success "Query Service スキーマを作成しました"

if mix ecto.migrate >> "$SETUP_LOG" 2>&1; then
    success "Query Service のマイグレーションが完了しました"
else
    error "Query Service のマイグレーションに失敗しました。詳細は $SETUP_LOG を確認してください"
    exit 1
fi

# ==============================================================================
# 完了
# ==============================================================================

section "✨ セットアップ完了！"

log "${GREEN}初回セットアップが正常に完了しました！${NC}"
log ""
log "次のステップ:"
log "  1. サービスを起動: ${CYAN}./scripts/start.sh${NC}"
log "  2. シードデータを投入: ${CYAN}./scripts/seed.sh${NC}"
log ""
log "または、すべてを一度に実行:"
log "  ${CYAN}./scripts/dev.sh${NC}"
log ""
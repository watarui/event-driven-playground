#!/bin/bash

# ==============================================================================
# 初回セットアップスクリプト
# Docker起動と依存関係の取得
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

# Docker Compose 起動
info "Docker コンテナを起動しています..."
if docker compose up -d >> "$SETUP_LOG" 2>&1; then
    success "Docker コンテナを起動しました"
else
    error "Docker コンテナの起動に失敗しました。詳細は $SETUP_LOG を確認してください"
    exit 1
fi

# Firestore エミュレータの起動確認
info "Firestore エミュレータの起動を待機しています..."
if wait_for_firestore_emulator; then
    success "Firestore エミュレータが起動しました"
else
    error "Firestore エミュレータの起動に失敗しました"
    log "Docker ログを確認してください: ${CYAN}docker compose logs firestore${NC}"
    exit 1
fi

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

# フロントエンドの依存関係
if [ -d "$PROJECT_ROOT/frontend" ]; then
    cd "$PROJECT_ROOT/frontend"
    info "npm install を実行しています..."
    if npm install >> "$SETUP_LOG" 2>&1; then
        success "フロントエンドの依存関係を取得しました"
    else
        warning "フロントエンドの依存関係の取得に失敗しました。詳細は $SETUP_LOG を確認してください"
    fi
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
log "  ${CYAN}make start${NC}"
log ""
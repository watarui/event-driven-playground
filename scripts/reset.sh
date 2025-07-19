#!/bin/bash

# ==============================================================================
# 完全リセットスクリプト
# すべてを停止し、データを削除してから再セットアップ
# ==============================================================================

set -e

# 共通ライブラリの読み込み
source "$(dirname "$0")/lib/common.sh"

# ログファイルの準備
ensure_log_dir
LOG_FILE=$(generate_log_filename "reset")
log_to_file "===== 完全リセット開始 ====="

section "🔄 完全リセット"
info "ログファイル: $LOG_FILE"

warning "このスクリプトはすべてのデータを削除します！"
echo -n "続行しますか？ (y/N): "
read -r response
if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    info "キャンセルしました"
    exit 0
fi

# ==============================================================================
# すべてのサービスを停止
# ==============================================================================

info "すべてのサービスを停止しています..."
log_to_file "stop.sh --all を実行中..."
"$SCRIPT_DIR/stop.sh" --all >> "$LOG_FILE" 2>&1
log_to_file "サービス停止完了"

# ==============================================================================
# データベースの削除
# ==============================================================================

section "🗑️  データベース削除"

if is_docker_running && docker compose ps | grep -q postgres; then
    # Docker コンテナを再起動してクリーンな状態にする
    info "PostgreSQL コンテナを再作成しています..."
    cd "$PROJECT_ROOT"
    log_to_file "Docker コンテナを削除中..."
    docker compose rm -sf postgres-event-store postgres-command postgres-query >> "$LOG_FILE" 2>&1
    log_to_file "Docker ボリュームを削除中..."
    docker volume rm -f event-driven-playground_postgres-event-store-data event-driven-playground_postgres-command-data event-driven-playground_postgres-query-data >> "$LOG_FILE" 2>&1 || true
    
    # コンテナを再作成
    log_to_file "Docker コンテナを再作成中..."
    docker compose up -d postgres-event-store postgres-command postgres-query >> "$LOG_FILE" 2>&1
    
    # PostgreSQL の起動を待つ
    info "PostgreSQL の起動を待機しています..."
    sleep 10
    
    success "データベースをクリーンな状態にリセットしました"
    log_to_file "データベースのリセット完了"
else
    warning "Docker が起動していないため、データベースの削除をスキップしました"
fi

# ==============================================================================
# ビルドアーティファクトの削除
# ==============================================================================

section "🧹 ビルドアーティファクトの削除"

info "_build ディレクトリを削除しています..."
cd "$PROJECT_ROOT"
log_to_file "_build ディレクトリを削除中..."
rm -rf _build
rm -rf apps/*/_build
log_to_file "_build ディレクトリを削除しました"

info "deps ディレクトリを削除しています..."
log_to_file "deps ディレクトリを削除中..."
rm -rf deps
rm -rf apps/*/deps
log_to_file "deps ディレクトリを削除しました"

success "ビルドアーティファクトを削除しました"

# ==============================================================================
# ログファイルの削除
# ==============================================================================

info "ログファイルを削除しています..."
rm -rf "$LOG_DIR"
mkdir -p "$LOG_DIR"
success "ログファイルを削除しました"

# ==============================================================================
# 再セットアップ
# ==============================================================================

section "🚀 再セットアップ"

info "セットアップスクリプトを実行しています..."
log_to_file "setup.sh を実行中..."
"$SCRIPT_DIR/setup.sh" >> "$LOG_FILE" 2>&1
log_to_file "setup.sh の実行完了"

# ==============================================================================
# 完了
# ==============================================================================

section "✨ リセット完了！"
log_to_file "===== 完全リセット完了 ====="

log ""
log "${GREEN}環境がクリーンな状態にリセットされました！${NC}"
log ""
log "次のステップ:"
log "  1. サービスを起動: ${CYAN}./scripts/start.sh${NC}"
log "  2. シードデータを投入: ${CYAN}./scripts/seed.sh${NC}"
log ""
log "または:"
log "  ${CYAN}./scripts/dev.sh${NC} で自動的に実行"
log ""
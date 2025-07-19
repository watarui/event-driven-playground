#!/bin/bash

# ==============================================================================
# サービス停止スクリプト
# Elixir サービスと Docker コンテナの停止
# ==============================================================================

set -e

# 共通ライブラリの読み込み
source "$(dirname "$0")/lib/common.sh"

# ログファイルの準備
ensure_log_dir
LOG_FILE=$(generate_log_filename "stop")
log_to_file "===== サービス停止開始 ====="

# オプション解析
STOP_DOCKER=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --all|-a)
            STOP_DOCKER=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--all|-a]"
            echo "  --all, -a: Docker コンテナも停止"
            exit 1
            ;;
    esac
done

section "🛑 サービス停止"
info "ログファイル: $LOG_FILE"

# ==============================================================================
# Elixir サービスの停止
# ==============================================================================

info "Elixir サービスを停止しています..."

# ポートごとにプロセスを停止
services_stopped=false
for port in $GRAPHQL_PORT $COMMAND_PORT $QUERY_PORT $FRONTEND_PORT; do
    if is_process_running $port; then
        log_to_file "ポート $port のプロセスを停止中..."
        stop_process_on_port $port
        log_to_file "ポート $port のプロセスを停止しました"
        services_stopped=true
    fi
done

if [ "$services_stopped" = true ]; then
    success "Elixir サービスを停止しました"
else
    info "起動中のサービスはありませんでした"
fi

# Elixir ノードのクリーンアップ
info "Elixir ノードをクリーンアップしています..."
log_to_file "epmd を終了中..."
epmd -kill 2>/dev/null || true
log_to_file "Elixir ノードのクリーンアップ完了"

# ==============================================================================
# Docker コンテナの停止（オプション）
# ==============================================================================

if [ "$STOP_DOCKER" = true ]; then
    section "🐳 Docker コンテナの停止"
    
    if are_containers_running; then
        info "Docker コンテナを停止しています..."
        log_to_file "docker compose down を実行中..."
        cd "$PROJECT_ROOT"
        if docker compose down >> "$LOG_FILE" 2>&1; then
            success "Docker コンテナを停止しました"
            log_to_file "Docker コンテナの停止完了"
        else
            show_log_on_error "Docker コンテナの停止に失敗しました"
        fi
    else
        info "起動中の Docker コンテナはありませんでした"
        log_to_file "Docker コンテナは起動していません"
    fi
else
    if are_containers_running; then
        info "Docker コンテナは起動したままです"
        log "  Docker も停止する場合: ${CYAN}./scripts/stop.sh --all${NC}"
    fi
fi

# ==============================================================================
# 完了
# ==============================================================================

section "✨ 停止完了"
log_to_file "===== サービス停止完了 ====="

log ""
log "次のコマンド:"
log "  サービスを再起動: ${CYAN}./scripts/start.sh${NC}"
log "  完全リセット: ${CYAN}./scripts/reset.sh${NC}"
log ""
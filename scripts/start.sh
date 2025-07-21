#!/bin/bash

# ==============================================================================
# サービス起動スクリプト
# Elixir サービスの起動とヘルスチェック
# ==============================================================================

set -e

# 共通ライブラリの読み込み
source "$(dirname "$0")/lib/common.sh"

# ログファイルの準備
ensure_log_dir
LOG_FILE=$(generate_log_filename "start")
log_to_file "===== サービス起動開始 ====="

# オプション解析
WITH_FRONTEND=false
WITH_SEED=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --frontend|-f)
            WITH_FRONTEND=true
            shift
            ;;
        --seed|-s)
            WITH_SEED=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--frontend|-f] [--seed|-s]"
            exit 1
            ;;
    esac
done

section "🚀 Event Driven Playground サービス起動"
info "ログファイル: $LOG_FILE"

# ==============================================================================
# 事前チェック
# ==============================================================================

ensure_log_dir

# Docker チェック
log_to_file "Docker コンテナの状態を確認中..."
if ! are_containers_running; then
    log_to_file "エラー: Docker コンテナが起動していません"
    show_log_on_error "Docker コンテナが起動していません"
    log "先に ${CYAN}docker compose up -d${NC} を実行してください"
    exit 1
fi
log_to_file "Docker コンテナは正常に起動しています"

# Firestore エミュレータ接続チェック
info "Firestore エミュレータへの接続を確認しています..."
log_to_file "Firestore エミュレータ (port $FIRESTORE_PORT) への接続を確認中..."

echo -n "  Firestore エミュレータへの接続を確認"
if check_firestore_emulator; then
    echo -e " ${GREEN}✓${NC}"
    log_to_file "Firestore エミュレータへの接続成功"
else
    echo -e " ${RED}✗${NC}"
    log_to_file "エラー: Firestore エミュレータに接続できません"
    show_log_on_error "Firestore エミュレータに接続できません"
    exit 1
fi
success "Firestore エミュレータに接続できました"

# ==============================================================================
# 既存プロセスの停止
# ==============================================================================

info "既存のプロセスを停止しています..."
for port in $GRAPHQL_PORT $COMMAND_PORT $QUERY_PORT; do
    stop_process_on_port $port
done

if [ "$WITH_FRONTEND" = true ]; then
    stop_process_on_port $FRONTEND_PORT
fi

# ==============================================================================
# サービス起動
# ==============================================================================

section "🔧 バックエンドサービスの起動"

# Command Service
info "Command Service を起動しています..."
cd "$PROJECT_ROOT/apps/command_service"
log_to_file "Command Service を起動: PORT=$COMMAND_PORT"
PORT=$COMMAND_PORT elixir --sname command -S mix run --no-halt > "$LOG_DIR/command_service.log" 2>&1 &
COMMAND_PID=$!
log "  PID: $COMMAND_PID (Port: $COMMAND_PORT)"
log_to_file "Command Service PID: $COMMAND_PID"

# Query Service
info "Query Service を起動しています..."
cd "$PROJECT_ROOT/apps/query_service"
log_to_file "Query Service を起動: PORT=$QUERY_PORT"
PORT=$QUERY_PORT elixir --sname query -S mix run --no-halt > "$LOG_DIR/query_service.log" 2>&1 &
QUERY_PID=$!
log "  PID: $QUERY_PID (Port: $QUERY_PORT)"
log_to_file "Query Service PID: $QUERY_PID"

# Client Service (GraphQL)
info "Client Service (GraphQL) を起動しています..."
cd "$PROJECT_ROOT/apps/client_service"
log_to_file "Client Service を起動: PORT=$GRAPHQL_PORT"
PORT=$GRAPHQL_PORT elixir --sname client -S mix phx.server > "$LOG_DIR/client_service.log" 2>&1 &
CLIENT_PID=$!
log "  PID: $CLIENT_PID (Port: $GRAPHQL_PORT)"
log_to_file "Client Service PID: $CLIENT_PID"

# ==============================================================================
# ヘルスチェック
# ==============================================================================

section "🏥 ヘルスチェック"

# サービスの起動を待つ
info "サービスの起動を待機しています..."
log_to_file "サービスの起動を待機中..."
sleep 5

# Command Service
log_to_file "Command Service のヘルスチェック中..."
wait_for_port $COMMAND_PORT "Command Service" &
pid=$!
echo -n "  Command Service (Port: $COMMAND_PORT)"
show_spinner $pid
if wait $pid; then
    echo -e " ${GREEN}✓${NC} 起動完了"
    log_to_file "Command Service の起動が完了しました"
else
    echo -e " ${RED}✗${NC} 起動失敗"
    log_to_file "エラー: Command Service の起動に失敗しました"
    show_log_on_error "起動失敗"
    exit 1
fi

# Query Service
log_to_file "Query Service のヘルスチェック中..."
wait_for_port $QUERY_PORT "Query Service" &
pid=$!
echo -n "  Query Service (Port: $QUERY_PORT)"
show_spinner $pid
if wait $pid; then
    echo -e " ${GREEN}✓${NC} 起動完了"
    log_to_file "Query Service の起動が完了しました"
else
    echo -e " ${RED}✗${NC} 起動失敗"
    log_to_file "エラー: Query Service の起動に失敗しました"
    show_log_on_error "起動失敗"
    exit 1
fi

# GraphQL API
log_to_file "GraphQL API のヘルスチェック中..."
wait_for_port $GRAPHQL_PORT "GraphQL" &
pid=$!
echo -n "  GraphQL API (Port: $GRAPHQL_PORT)"
show_spinner $pid
if wait $pid; then
    # GraphQL エンドポイントの確認
    sleep 2
    check_service_health "http://localhost:$GRAPHQL_PORT/graphql" "GraphQL" &
    pid=$!
    echo -n "  GraphQL エンドポイント確認"
    show_spinner $pid
    if wait $pid; then
        echo -e " ${GREEN}✓${NC} 起動完了"
        log_to_file "GraphQL API の起動が完了しました"
    else
        echo -e " ${YELLOW}!${NC} 起動中"
        log_to_file "GraphQL API は起動中です"
    fi
else
    echo -e " ${RED}✗${NC} 起動失敗"
    log_to_file "エラー: GraphQL API の起動に失敗しました"
    show_log_on_error "起動失敗"
    exit 1
fi

# ==============================================================================
# フロントエンド起動（オプション）
# ==============================================================================

if [ "$WITH_FRONTEND" = true ]; then
    section "🎨 フロントエンドの起動"
    
    cd "$PROJECT_ROOT/frontend"
    info "Next.js を起動しています..."
    log_to_file "Frontend を起動: PORT=$FRONTEND_PORT"
    
    # Next.js の出力をそのまま表示
    bun run dev &
    FRONTEND_PID=$!
    log "  PID: $FRONTEND_PID (Port: $FRONTEND_PORT)"
    log_to_file "Frontend PID: $FRONTEND_PID"
    
    # シード投入のチェック（--seed オプションがある場合）
    if [ "$WITH_SEED" = true ]; then
        section "🌱 データベース状態の確認"
        info "データベースの状態を確認しています..."
        
        # GraphQL が起動するまで待つ
        sleep 3
        
        # カテゴリ数を確認
        CATEGORY_COUNT=$(curl -s -X POST "http://localhost:$GRAPHQL_PORT/graphql" \
            -H "Content-Type: application/json" \
            -d '{"query":"{ categories { id } }"}' 2>/dev/null | \
            jq '.data.categories | length' 2>/dev/null || echo "0")
        
        if [ "$CATEGORY_COUNT" = "0" ] || [ -z "$CATEGORY_COUNT" ]; then
            warning "データベースが空です。シードデータを投入します"
            "${SCRIPT_DIR}/seed.sh"
        else
            info "既存データがあります（$CATEGORY_COUNT カテゴリ）。シード投入をスキップします"
        fi
    fi
fi

# ==============================================================================
# 完了メッセージ
# ==============================================================================

section "✨ 起動完了！"
log_to_file "===== サービス起動完了 ===="

log ""
log "📋 アクセス URL:"
log "  ${GREEN}GraphQL API:${NC} http://localhost:$GRAPHQL_PORT/graphql"
log "  ${GREEN}GraphiQL (開発用 UI):${NC} http://localhost:$GRAPHQL_PORT/graphiql"
if [ "$WITH_FRONTEND" = true ]; then
    log "  ${GREEN}Monitor Dashboard:${NC} http://localhost:$FRONTEND_PORT"
fi
log ""
log "📌 便利なコマンド:"
log "  ログを確認: ${CYAN}./scripts/logs.sh${NC}"
log "  サービスを停止: ${CYAN}./scripts/stop.sh${NC}"
log "  シードデータ投入: ${CYAN}./scripts/seed.sh${NC}"
log ""

# バックグラウンドプロセスの監視
info "Ctrl+C でサービスを停止します"

# 終了処理
cleanup() {
    echo ""
    warning "サービスを停止しています..."
    log_to_file "Ctrl+C を検出 - サービスを停止中..."
    kill $COMMAND_PID $QUERY_PID $CLIENT_PID 2>/dev/null || true
    if [ "$WITH_FRONTEND" = true ] && [ ! -z "$FRONTEND_PID" ]; then
        kill $FRONTEND_PID 2>/dev/null || true
    fi
    log_to_file "サービスを停止しました"
    success "サービスを停止しました"
    exit 0
}

trap cleanup INT

# プロセスの監視
while kill -0 $COMMAND_PID $QUERY_PID $CLIENT_PID 2>/dev/null; do
    sleep 1
done
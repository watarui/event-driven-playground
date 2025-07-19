#!/bin/bash

# ==============================================================================
# 開発用統合コマンド
# 状態を確認して適切なセットアップ/起動を行う
# ==============================================================================

set -e

# 共通ライブラリの読み込み
source "$(dirname "$0")/lib/common.sh"

# ログファイルの準備
ensure_log_dir
LOG_FILE=$(generate_log_filename "dev")
log_to_file "===== 開発環境統合実行開始 ====="

# オプション解析
WITH_FRONTEND=false
WITH_SEED=false
FORCE_RESET=false

show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -f, --frontend    フロントエンドも起動"
    echo "  -s, --seed        シードデータを投入"
    echo "  -r, --reset       強制的にリセットしてから起動"
    echo "  -h, --help        このヘルプを表示"
    echo ""
    echo "Examples:"
    echo "  $0                # バックエンドのみ起動"
    echo "  $0 -f             # フロントエンドも含めて起動"
    echo "  $0 -f -s          # フロントエンド起動＋シードデータ投入"
    echo "  $0 -r             # リセットしてから起動"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--frontend)
            WITH_FRONTEND=true
            shift
            ;;
        -s|--seed)
            WITH_SEED=true
            shift
            ;;
        -r|--reset)
            FORCE_RESET=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

section "🚀 Event Driven Playground 開発環境"
info "ログファイル: $LOG_FILE"

log_to_file "オプション: WITH_FRONTEND=$WITH_FRONTEND, WITH_SEED=$WITH_SEED, FORCE_RESET=$FORCE_RESET"

# ==============================================================================
# 強制リセット
# ==============================================================================

if [ "$FORCE_RESET" = true ]; then
    warning "強制リセットが要求されました"
    log_to_file "強制リセットを実行中..."
    "$SCRIPT_DIR/reset.sh" >> "$LOG_FILE" 2>&1
    log_to_file "リセット完了"
    # reset.sh がセットアップまで完了するので、start.sh に進む
    NEED_SETUP=false
else
    # ==============================================================================
    # 環境チェック
    # ==============================================================================
    
    info "環境をチェックしています..."
    log_to_file "環境チェックを開始"
    
    NEED_SETUP=false
    
    # Docker チェック
    log_to_file "Docker の状態を確認中..."
    run_with_spinner "  Docker の状態を確認" is_docker_running
    if [ $? -ne 0 ]; then
        log_to_file "エラー: Docker が起動していません"
        error "Docker が起動していません"
        exit 1
    fi
    
    run_with_spinner "  Docker コンテナを確認" are_containers_running
    if [ $? -ne 0 ]; then
        warning "    Docker コンテナが起動していません"
        NEED_SETUP=true
    fi
    
    # データベースチェック
    if are_containers_running; then
        # Event Store DB
        database_exists "event_driven_playground_event_dev" 5432 > /dev/null 2>&1 &
        pid=$!
        echo -n "  Event Store DB を確認"
        show_spinner $pid
        if wait $pid; then
            echo -e " ${GREEN}✓${NC}"
        else
            echo -e " ${YELLOW}!${NC} 作成が必要"
            NEED_SETUP=true
        fi
        
        # Command DB
        database_exists "event_driven_playground_command_dev" 5433 > /dev/null 2>&1 &
        pid=$!
        echo -n "  Command DB を確認"
        show_spinner $pid
        if wait $pid; then
            echo -e " ${GREEN}✓${NC}"
        else
            echo -e " ${YELLOW}!${NC} 作成が必要"
            NEED_SETUP=true
        fi
        
        # Query DB
        database_exists "event_driven_playground_query_dev" 5434 > /dev/null 2>&1 &
        pid=$!
        echo -n "  Query DB を確認"
        show_spinner $pid
        if wait $pid; then
            echo -e " ${GREEN}✓${NC}"
        else
            echo -e " ${YELLOW}!${NC} 作成が必要"
            NEED_SETUP=true
        fi
    fi
    
    # 依存関係チェック
    echo -n "  依存関係を確認"
    ( [ -d "$PROJECT_ROOT/deps" ] && [ -d "$PROJECT_ROOT/_build" ] ) &
    pid=$!
    show_spinner $pid
    if wait $pid; then
        echo -e " ${GREEN}✓${NC}"
    else
        echo -e " ${YELLOW}!${NC} インストールが必要"
        NEED_SETUP=true
    fi
    
    echo ""  # 空行を追加
fi

# ==============================================================================
# セットアップ実行（必要な場合）
# ==============================================================================

if [ "$NEED_SETUP" = true ]; then
    info "初回セットアップが必要です"
    log_to_file "setup.sh を実行中..."
    if "$SCRIPT_DIR/setup.sh" >> "$LOG_FILE" 2>&1; then
        log_to_file "setup.sh の実行完了"
    else
        log_to_file "エラー: セットアップに失敗しました"
        show_log_on_error "セットアップに失敗しました"
        exit 1
    fi
fi

# ==============================================================================
# サービス起動
# ==============================================================================

# すでに起動しているかチェック
if is_process_running $GRAPHQL_PORT; then
    warning "サービスはすでに起動しています"
    echo -n "再起動しますか？ (y/N): "
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        "$SCRIPT_DIR/stop.sh"
    else
        info "既存のサービスを使用します"
        SKIP_START=true
    fi
fi

if [ "${SKIP_START:-false}" != true ]; then
    log_to_file "サービスを起動中..."
    section "🚀 サービス起動"
    if [ "$WITH_FRONTEND" = true ]; then
        "$SCRIPT_DIR/start.sh" --frontend 2>&1 | tee -a "$LOG_FILE" &
    else
        "$SCRIPT_DIR/start.sh" 2>&1 | tee -a "$LOG_FILE" &
    fi
    START_PID=$!
    
    # 起動完了を待つ
    log_to_file "サービスの起動を待機中..."
fi

# ==============================================================================
# シードデータ投入（オプション）
# ==============================================================================

if [ "$WITH_SEED" = true ]; then
    section "🌱 シードデータ投入"
    
    # GraphQL が利用可能になるまで待つ
    info "GraphQL API の準備を待っています..."
    max_attempts=30
    attempt=0
    while ! check_service_health "http://localhost:$GRAPHQL_PORT/graphql" "GraphQL"; do
        attempt=$((attempt + 1))
        if [ $attempt -gt $max_attempts ]; then
            error "GraphQL API が起動しませんでした"
            exit 1
        fi
        sleep 2
    done
    
    log_to_file "seed.sh を実行中..."
    if "$SCRIPT_DIR/seed.sh" >> "$LOG_FILE" 2>&1; then
        log_to_file "シードデータ投入完了"
    else
        log_to_file "エラー: シードデータ投入に失敗しました"
        show_log_on_error "シードデータ投入に失敗しました"
    fi
fi

# ==============================================================================
# 完了
# ==============================================================================

log_to_file "===== 開発環境統合実行完了 ====="

if [ "${SKIP_START:-false}" != true ]; then
    # start.sh のプロセスを待つ
    wait $START_PID
fi
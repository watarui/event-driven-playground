#!/bin/bash

# ==============================================================================
# ログ表示スクリプト
# サービスのログをリアルタイムで表示
# ==============================================================================

set -e

# 共通ライブラリの読み込み
source "$(dirname "$0")/lib/common.sh"

# デフォルト設定
SERVICE="all"
FOLLOW=true

# ヘルプ表示
show_help() {
    echo "Usage: $0 [options] [service]"
    echo ""
    echo "Services:"
    echo "  all       すべてのサービス（デフォルト）"
    echo "  command   Command Service"
    echo "  query     Query Service"
    echo "  client    Client Service (GraphQL)"
    echo "  frontend  Frontend (Next.js)"
    echo ""
    echo "Options:"
    echo "  -f, --follow    ログをリアルタイムで追跡（デフォルト）"
    echo "  -n, --no-follow ログの最後の部分のみ表示"
    echo "  -h, --help      このヘルプを表示"
    echo ""
    echo "Examples:"
    echo "  $0              # すべてのログをリアルタイム表示"
    echo "  $0 client       # GraphQL のログのみ表示"
    echo "  $0 -n command   # Command Service の最新ログを表示"
}

# オプション解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--follow)
            FOLLOW=true
            shift
            ;;
        -n|--no-follow)
            FOLLOW=false
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        all|command|query|client|frontend)
            SERVICE=$1
            shift
            ;;
        *)
            echo "Unknown option or service: $1"
            show_help
            exit 1
            ;;
    esac
done

# ログディレクトリの確認
if [ ! -d "$LOG_DIR" ]; then
    error "ログディレクトリが存在しません: $LOG_DIR"
    exit 1
fi

# ログファイルのパスを設定
case $SERVICE in
    all)
        LOG_FILES=(
            "$LOG_DIR/command_service.log"
            "$LOG_DIR/query_service.log"
            "$LOG_DIR/client_service.log"
            "$LOG_DIR/frontend.log"
        )
        ;;
    command)
        LOG_FILES=("$LOG_DIR/command_service.log")
        ;;
    query)
        LOG_FILES=("$LOG_DIR/query_service.log")
        ;;
    client)
        LOG_FILES=("$LOG_DIR/client_service.log")
        ;;
    frontend)
        LOG_FILES=("$LOG_DIR/frontend.log")
        ;;
esac

# 存在するログファイルのみフィルタ
EXISTING_LOGS=()
for file in "${LOG_FILES[@]}"; do
    if [ -f "$file" ]; then
        EXISTING_LOGS+=("$file")
    fi
done

if [ ${#EXISTING_LOGS[@]} -eq 0 ]; then
    warning "表示するログファイルがありません"
    info "サービスが起動していることを確認してください: ${CYAN}./scripts/start.sh${NC}"
    exit 0
fi

# ログ表示
section "📋 ログ表示"

if [ "$SERVICE" = "all" ]; then
    info "すべてのサービスのログを表示します"
else
    info "$SERVICE のログを表示します"
fi

if [ "$FOLLOW" = true ]; then
    info "Ctrl+C で終了"
    echo ""
    
    # tail -f で複数ファイルを同時に追跡
    if [ ${#EXISTING_LOGS[@]} -eq 1 ]; then
        tail -f "${EXISTING_LOGS[0]}"
    else
        # 複数ファイルの場合、ファイル名を表示
        tail -f "${EXISTING_LOGS[@]}" | while read -r line; do
            # tail の "==> filename <==" 形式を検出
            if [[ $line =~ ^==\>.+\<==$ ]]; then
                filename=$(echo "$line" | sed 's/==> //; s/ <==//')
                basename_file=$(basename "$filename" .log)
                
                case $basename_file in
                    command_service)
                        echo -e "\n${YELLOW}[COMMAND]${NC}"
                        ;;
                    query_service)
                        echo -e "\n${BLUE}[QUERY]${NC}"
                        ;;
                    client_service)
                        echo -e "\n${GREEN}[GRAPHQL]${NC}"
                        ;;
                    frontend)
                        echo -e "\n${CYAN}[FRONTEND]${NC}"
                        ;;
                esac
            else
                echo "$line"
            fi
        done
    fi
else
    # 最後の50行を表示
    for file in "${EXISTING_LOGS[@]}"; do
        if [ ${#EXISTING_LOGS[@]} -gt 1 ]; then
            basename_file=$(basename "$file" .log)
            case $basename_file in
                command_service)
                    echo -e "\n${YELLOW}=== Command Service ===${NC}"
                    ;;
                query_service)
                    echo -e "\n${BLUE}=== Query Service ===${NC}"
                    ;;
                client_service)
                    echo -e "\n${GREEN}=== Client Service (GraphQL) ===${NC}"
                    ;;
                frontend)
                    echo -e "\n${CYAN}=== Frontend ===${NC}"
                    ;;
            esac
        fi
        tail -n 50 "$file"
    done
fi
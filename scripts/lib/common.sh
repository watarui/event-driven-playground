#!/bin/bash

# ==============================================================================
# 共通ライブラリ - 色付き出力、エラーハンドリング、共通設定
# ==============================================================================

# 色定義
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

# プロジェクトパス
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
export LOG_DIR="$PROJECT_ROOT/logs"

# データベース設定
export PGPASSWORD=postgres
export MIX_ENV=dev

# ポート設定
export GRAPHQL_PORT=4000
export COMMAND_PORT=4001
export QUERY_PORT=4002
export FRONTEND_PORT=3000

# ==============================================================================
# 出力関数
# ==============================================================================

log() {
    echo -e "$1"
}

info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ==============================================================================
# ヘルスチェック関数
# ==============================================================================

wait_for_port() {
    local port=$1
    local service=$2
    local max_attempts=30
    local attempt=0
    
    while ! nc -z localhost $port 2>/dev/null; do
        attempt=$((attempt + 1))
        if [ $attempt -eq $max_attempts ]; then
            return 1
        fi
        sleep 1
    done
    return 0
}

check_postgres() {
    local port=$1
    pg_isready -h localhost -p $port -U postgres > /dev/null 2>&1
}

check_service_health() {
    local url=$1
    local service=$2
    
    # GraphQL エンドポイントの場合は POST でチェック
    if [[ "$url" == *"/graphql" ]]; then
        if curl -s -X POST "$url" -H "Content-Type: application/json" -d '{"query":"{ __typename }"}' | grep -q "__typename"; then
            return 0
        else
            return 1
        fi
    else
        if curl -s -f -o /dev/null "$url"; then
            return 0
        else
            return 1
        fi
    fi
}

# ==============================================================================
# プロセス管理
# ==============================================================================

is_process_running() {
    local port=$1
    lsof -i :$port > /dev/null 2>&1
}

stop_process_on_port() {
    local port=$1
    local pid=$(lsof -ti :$port 2>/dev/null)
    if [ ! -z "$pid" ]; then
        kill $pid 2>/dev/null || kill -9 $pid 2>/dev/null
        sleep 1
    fi
}

# ==============================================================================
# Docker 関連
# ==============================================================================

is_docker_running() {
    docker ps > /dev/null 2>&1
}

are_containers_running() {
    local count=$(docker compose ps --format "table {{.Service}}" --filter "status=running" 2>/dev/null | grep -v "SERVICE" | wc -l)
    [ $count -gt 0 ]
}

# ==============================================================================
# データベース関連
# ==============================================================================

database_exists() {
    local db_name=$1
    local port=$2
    psql -h localhost -p $port -U postgres -lqt | cut -d \| -f 1 | grep -qw "$db_name"
}

create_database_if_not_exists() {
    local db_name=$1
    local port=$2
    
    if ! database_exists "$db_name" "$port"; then
        info "データベース $db_name を作成しています..."
        psql -h localhost -p $port -U postgres -c "CREATE DATABASE \"$db_name\";" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            success "データベース $db_name を作成しました"
        else
            error "データベース $db_name の作成に失敗しました"
            return 1
        fi
    fi
    return 0
}

# ==============================================================================
# ログ関連
# ==============================================================================

ensure_log_dir() {
    mkdir -p "$LOG_DIR"
}

# タイムスタンプ付きログファイル名を生成
generate_log_filename() {
    local prefix=$1
    echo "$LOG_DIR/${prefix}_$(date +%Y%m%d_%H%M%S).log"
}

# ログファイルに記録
log_to_file() {
    local message=$1
    local log_file=${2:-$LOG_FILE}
    if [ -n "$log_file" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$log_file"
    fi
}

# 画面とログファイルの両方に出力
log_both() {
    local message=$1
    log "$message"
    log_to_file "$message"
}

# コマンド実行とログ記録
run_with_log() {
    local command=$1
    local description=$2
    log_to_file "実行: $command"
    
    if eval "$command" >> "${LOG_FILE:-/dev/null}" 2>&1; then
        log_to_file "成功: $description"
        return 0
    else
        local exit_code=$?
        log_to_file "失敗: $description (exit code: $exit_code)"
        return $exit_code
    fi
}

# エラー時にログファイルパスを表示
show_log_on_error() {
    if [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then
        error "$1"
        log "詳細は以下のログファイルを確認してください:"
        log "  ${CYAN}$LOG_FILE${NC}"
    else
        error "$1"
    fi
}

# ==============================================================================
# スピナー表示
# ==============================================================================

# シンプルなスピナー表示
show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Unicode スピナー表示
show_unicode_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⣾⣽⣻⢿⡿⣟⣯⣷'
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf " %c  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# メッセージ付きスピナー表示
show_spinner_with_message() {
    local message=$1
    local pid=$2
    local delay=0.1
    local spinstr='⣾⣽⣻⢿⡿⣟⣯⣷'
    
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\r${CYAN}%c${NC} %s" "$spinstr" "$message"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\r\033[K"  # 行をクリア
}

# コマンドをスピナー付きで実行
run_with_spinner() {
    local message=$1
    shift
    local command="$@"
    
    # バックグラウンドで実行
    eval "$command" > /dev/null 2>&1 &
    local pid=$!
    
    echo -n "$message"
    show_spinner $pid
    wait $pid
    local result=$?
    
    if [ $result -eq 0 ]; then
        echo -e " ${GREEN}✓${NC}"
    else
        echo -e " ${RED}✗${NC}"
    fi
    
    return $result
}

# ==============================================================================
# 終了処理
# ==============================================================================

cleanup() {
    echo ""
    warning "処理を中断しています..."
    exit 1
}

# Ctrl+C のハンドリング
trap cleanup INT
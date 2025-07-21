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

# 環境設定
export MIX_ENV=dev
export FIRESTORE_EMULATOR_HOST=localhost:8090
export FIRESTORE_PROJECT_ID=demo-project

# ポート設定
export GRAPHQL_PORT=4000
export COMMAND_PORT=4081
export QUERY_PORT=4082
export FRONTEND_PORT=3000
export FIRESTORE_PORT=8090

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
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ==============================================================================
# ポート待機とヘルスチェック
# ==============================================================================

wait_for_port() {
    local port=$1
    local service=$2
    local max_attempts=30
    local attempt=0
    
    while ! nc -z localhost $port > /dev/null 2>&1; do
        if [ $attempt -ge $max_attempts ]; then
            return 1
        fi
        sleep 1
        ((attempt++))
    done
    return 0
}

check_service_health() {
    local url=$1
    local service=$2
    local max_attempts=10
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s -f -o /dev/null "$url"; then
            return 0
        fi
        sleep 1
        ((attempt++))
    done
    return 1
}

check_port() {
    local port=$1
    nc -z localhost $port > /dev/null 2>&1
}

check_url() {
    local url=$1
    if command -v curl &> /dev/null; then
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
# Firestore エミュレータ関連
# ==============================================================================

check_firestore_emulator() {
    local port=${1:-$FIRESTORE_PORT}
    curl -s -f -o /dev/null "http://localhost:$port/" 2>/dev/null
}

wait_for_firestore_emulator() {
    local port=${1:-$FIRESTORE_PORT}
    local max_attempts=30
    local attempt=0
    
    while ! check_firestore_emulator $port; do
        if [ $attempt -ge $max_attempts ]; then
            return 1
        fi
        sleep 1
        ((attempt++))
    done
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
#!/bin/bash

# ==============================================================================
# シードデータ投入スクリプト
# GraphQL 経由でサンプルデータを投入
# ==============================================================================

set -e

# 共通ライブラリの読み込み
source "$(dirname "$0")/lib/common.sh"

# ログファイルの準備
ensure_log_dir
LOG_FILE=$(generate_log_filename "seed")
log_to_file "===== シードデータ投入開始 ====="

section "🌱 シードデータ投入"
info "ログファイル: $LOG_FILE"

# GraphQL エンドポイント
GRAPHQL_URL="http://localhost:$GRAPHQL_PORT/graphql"

# ==============================================================================
# サービスチェック
# ==============================================================================

info "GraphQL サービスの接続を確認しています..."
log_to_file "GraphQL エンドポイント: $GRAPHQL_URL"

if ! check_service_health "$GRAPHQL_URL" "GraphQL"; then
    log_to_file "エラー: GraphQL サービスに接続できません"
    show_log_on_error "GraphQL サービスに接続できません"
    log "サービスが起動していることを確認してください: ${CYAN}./scripts/start.sh${NC}"
    exit 1
fi

success "GraphQL サービスに接続できました"
log_to_file "GraphQL サービスへの接続成功"

# ==============================================================================
# GraphQL mutation 実行関数
# ==============================================================================

execute_mutation() {
    local query=$1
    local description=$2
    
    echo -n "  $description... "
    log_to_file "Mutation 実行: $description"
    
    response=$(curl -s -X POST "$GRAPHQL_URL" \
        -H "Content-Type: application/json" \
        -d "$query" 2>/dev/null)
    
    # レスポンスをログに記録
    echo "$response" >> "$LOG_FILE"
    
    if echo "$response" | grep -q '"errors"'; then
        echo -e "${RED}失敗${NC}"
        local error_msg=$(echo "$response" | jq -r '.errors[0].message' 2>/dev/null || echo "不明なエラー")
        echo "    エラー: $error_msg"
        log_to_file "エラー: $description - $error_msg"
        return 1
    else
        echo -e "${GREEN}成功${NC}"
        log_to_file "成功: $description"
        return 0
    fi
}

# ==============================================================================
# カテゴリの作成
# ==============================================================================

section "📁 カテゴリ作成"

execute_mutation '{
  "query": "mutation { createCategory(input: { name: \"電子機器\", description: \"スマートフォン、タブレット、ノートパソコンなど\" }) { id name } }"
}' "電子機器"

execute_mutation '{
  "query": "mutation { createCategory(input: { name: \"書籍\", description: \"技術書、ビジネス書、小説など\" }) { id name } }"
}' "書籍"

execute_mutation '{
  "query": "mutation { createCategory(input: { name: \"衣料品\", description: \"Tシャツ、ジャケット、パンツなど\" }) { id name } }"
}' "衣料品"

execute_mutation '{
  "query": "mutation { createCategory(input: { name: \"食品・飲料\", description: \"スナック、飲み物、保存食品など\" }) { id name } }"
}' "食品・飲料"

execute_mutation '{
  "query": "mutation { createCategory(input: { name: \"家具・インテリア\", description: \"デスク、チェア、照明など\" }) { id name } }"
}' "家具・インテリア"

# ==============================================================================
# カテゴリIDの取得
# ==============================================================================

info "作成したカテゴリのIDを取得しています..."
log_to_file "カテゴリIDの取得中..."

CATEGORIES_RESPONSE=$(curl -s -X POST "$GRAPHQL_URL" \
  -H "Content-Type: application/json" \
  -d '{"query": "{ categories(limit: 10) { id name } }"}')

echo "$CATEGORIES_RESPONSE" >> "$LOG_FILE"

# カテゴリIDを抽出
ELECTRONICS_ID=$(echo "$CATEGORIES_RESPONSE" | jq -r '.data.categories[] | select(.name == "電子機器") | .id' 2>/dev/null)
BOOKS_ID=$(echo "$CATEGORIES_RESPONSE" | jq -r '.data.categories[] | select(.name == "書籍") | .id' 2>/dev/null)
CLOTHING_ID=$(echo "$CATEGORIES_RESPONSE" | jq -r '.data.categories[] | select(.name == "衣料品") | .id' 2>/dev/null)
FOOD_ID=$(echo "$CATEGORIES_RESPONSE" | jq -r '.data.categories[] | select(.name == "食品・飲料") | .id' 2>/dev/null)
FURNITURE_ID=$(echo "$CATEGORIES_RESPONSE" | jq -r '.data.categories[] | select(.name == "家具・インテリア") | .id' 2>/dev/null)

# ==============================================================================
# 商品の作成
# ==============================================================================

section "📦 商品作成"

# 電子機器
if [ -n "$ELECTRONICS_ID" ]; then
    execute_mutation "{
        \"query\": \"mutation { createProduct(input: { name: \\\"スマートフォン X1\\\", description: \\\"最新の5G対応スマートフォン\\\", price: 89900, categoryId: \\\"$ELECTRONICS_ID\\\", stockQuantity: 50 }) { id name } }\"
    }" "スマートフォン X1"
    
    execute_mutation "{
        \"query\": \"mutation { createProduct(input: { name: \\\"ノートパソコン Pro\\\", description: \\\"高性能ビジネスノートPC\\\", price: 149900, categoryId: \\\"$ELECTRONICS_ID\\\", stockQuantity: 30 }) { id name } }\"
    }" "ノートパソコン Pro"
    
    execute_mutation "{
        \"query\": \"mutation { createProduct(input: { name: \\\"ワイヤレスイヤホン\\\", description: \\\"ノイズキャンセリング機能付き\\\", price: 19900, categoryId: \\\"$ELECTRONICS_ID\\\", stockQuantity: 100 }) { id name } }\"
    }" "ワイヤレスイヤホン"
fi

# 書籍
if [ -n "$BOOKS_ID" ]; then
    execute_mutation "{
        \"query\": \"mutation { createProduct(input: { name: \\\"Elixir実践ガイド\\\", description: \\\"Elixir/Phoenix開発の実践的な解説書\\\", price: 3800, categoryId: \\\"$BOOKS_ID\\\", stockQuantity: 200 }) { id name } }\"
    }" "Elixir実践ガイド"
    
    execute_mutation "{
        \"query\": \"mutation { createProduct(input: { name: \\\"マイクロサービス設計\\\", description: \\\"マイクロサービスアーキテクチャ入門\\\", price: 4200, categoryId: \\\"$BOOKS_ID\\\", stockQuantity: 150 }) { id name } }\"
    }" "マイクロサービス設計"
    
    execute_mutation "{
        \"query\": \"mutation { createProduct(input: { name: \\\"CQRS/ES入門\\\", description: \\\"コマンドクエリ責務分離とイベントソーシング\\\", price: 3500, categoryId: \\\"$BOOKS_ID\\\", stockQuantity: 100 }) { id name } }\"
    }" "CQRS/ES入門"
fi

# 衣料品
if [ -n "$CLOTHING_ID" ]; then
    execute_mutation "{
        \"query\": \"mutation { createProduct(input: { name: \\\"エンジニアTシャツ\\\", description: \\\"プログラミング言語ロゴ入り\\\", price: 2900, categoryId: \\\"$CLOTHING_ID\\\", stockQuantity: 200 }) { id name } }\"
    }" "エンジニアTシャツ"
    
    execute_mutation "{
        \"query\": \"mutation { createProduct(input: { name: \\\"パーカー（黒）\\\", description: \\\"快適なコットン100%パーカー\\\", price: 5900, categoryId: \\\"$CLOTHING_ID\\\", stockQuantity: 80 }) { id name } }\"
    }" "パーカー（黒）"
fi

# ==============================================================================
# 注文の作成
# ==============================================================================

section "🛒 サンプル注文作成"

# 商品IDを取得
log_to_file "商品IDの取得中..."
PRODUCTS_RESPONSE=$(curl -s -X POST "$GRAPHQL_URL" \
  -H "Content-Type: application/json" \
  -d '{"query": "{ products(limit: 20) { id name price } }"}')

echo "$PRODUCTS_RESPONSE" >> "$LOG_FILE"

SMARTPHONE_ID=$(echo "$PRODUCTS_RESPONSE" | jq -r '.data.products[] | select(.name == "スマートフォン X1") | .id' 2>/dev/null)
ELIXIR_BOOK_ID=$(echo "$PRODUCTS_RESPONSE" | jq -r '.data.products[] | select(.name == "Elixir実践ガイド") | .id' 2>/dev/null)

# サンプルユーザーの注文
USER1_ID="550e8400-e29b-41d4-a716-446655440001"
USER2_ID="550e8400-e29b-41d4-a716-446655440002"

if [ -n "$SMARTPHONE_ID" ]; then
    execute_mutation "{
        \"query\": \"mutation { createOrder(input: { userId: \\\"$USER1_ID\\\", items: [{ productId: \\\"$SMARTPHONE_ID\\\", productName: \\\"スマートフォン X1\\\", quantity: 1, unitPrice: 89900 }] }) { success order { id status } } }\"
    }" "ユーザー1の注文（スマートフォン）"
fi

if [ -n "$ELIXIR_BOOK_ID" ]; then
    execute_mutation "{
        \"query\": \"mutation { createOrder(input: { userId: \\\"$USER2_ID\\\", items: [{ productId: \\\"$ELIXIR_BOOK_ID\\\", productName: \\\"Elixir実践ガイド\\\", quantity: 2, unitPrice: 3800 }] }) { success order { id status } } }\"
    }" "ユーザー2の注文（書籍）"
fi

# ==============================================================================
# 完了
# ==============================================================================

section "✨ シードデータ投入完了！"
log_to_file "===== シードデータ投入完了 ====="

log ""
log "データの確認方法:"
log "  GraphQL Playground: ${GREEN}http://localhost:$GRAPHQL_PORT/graphql${NC}"
log ""
log "サンプルクエリ:"
log "  { categories { id name productCount } }"
log "  { products(limit: 10) { id name price stockQuantity category { name } } }"
log "  { orders(limit: 10) { id status totalAmount createdAt } }"
log ""
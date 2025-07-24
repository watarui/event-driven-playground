#!/bin/bash

# テスト用の設定
GRAPHQL_URL="https://client-service-yfmozh2e7a-an.a.run.app/graphql"

echo "=== Testing GraphQL Mutation (Bypassing Auth) ==="

# 1. カテゴリ作成 mutation テスト（認証なし）
echo -e "\n1. Creating category via GraphQL mutation (no auth)..."
CREATE_RESPONSE=$(curl -s -X POST "$GRAPHQL_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation CreateCategory($input: CreateCategoryInput!) { createCategory(input: $input) { id name description } }",
    "variables": {
      "input": {
        "name": "Test Category No Auth",
        "description": "Testing without authentication"
      }
    }
  }')

echo "Create category response:"
echo "$CREATE_RESPONSE" | python3 -m json.tool

# 2. カテゴリ一覧を取得して確認
echo -e "\n2. Fetching categories to verify..."
LIST_RESPONSE=$(curl -s -X POST "$GRAPHQL_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "query { categories { id name description } }"
  }')

echo "Categories list:"
echo "$LIST_RESPONSE" | python3 -m json.tool
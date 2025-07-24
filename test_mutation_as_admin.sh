#!/bin/bash

# テスト用の設定
EMAIL="admin@example.com"  # ADMIN_EMAIL として設定されているメールアドレスを使用
PASSWORD="Admin123456!"
FIREBASE_API_KEY="AIzaSyD9mDKsGQ9f3jcaSJiRrF8_DtUL6t0sG7M"
GRAPHQL_URL="https://client-service-yfmozh2e7a-an.a.run.app/graphql"

echo "=== Testing GraphQL Mutation as Admin ==="

# 1. Firebase 認証
echo -e "\n1. Authenticating with Firebase as admin..."
AUTH_RESPONSE=$(curl -s -X POST "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"${EMAIL}\",
    \"password\": \"${PASSWORD}\",
    \"returnSecureToken\": true
  }")

# アカウントが存在しない場合は作成
if [[ ! "$AUTH_RESPONSE" =~ "idToken" ]]; then
  echo "Creating new admin account..."
  AUTH_RESPONSE=$(curl -s -X POST "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${FIREBASE_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"email\": \"${EMAIL}\",
      \"password\": \"${PASSWORD}\",
      \"returnSecureToken\": true
    }")
fi

ID_TOKEN=$(echo "$AUTH_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('idToken', ''))" 2>/dev/null)

if [ -z "$ID_TOKEN" ]; then
  echo "Authentication failed!"
  echo "$AUTH_RESPONSE" | python3 -m json.tool
  exit 1
fi

echo "✓ Authentication successful"

# 2. カテゴリ作成 mutation テスト
echo -e "\n2. Creating category via GraphQL mutation..."
CREATE_RESPONSE=$(curl -s -X POST "$GRAPHQL_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ID_TOKEN" \
  -d '{
    "query": "mutation CreateCategory($input: CreateCategoryInput!) { createCategory(input: $input) { id name description } }",
    "variables": {
      "input": {
        "name": "Admin Test Category",
        "description": "Testing with admin privileges"
      }
    }
  }')

echo "Create category response:"
echo "$CREATE_RESPONSE" | python3 -m json.tool

# カテゴリIDを抽出
CATEGORY_ID=$(echo "$CREATE_RESPONSE" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('data',{}).get('createCategory',{}).get('id',''))" 2>/dev/null)

if [ -n "$CATEGORY_ID" ] && [ "$CATEGORY_ID" != "" ]; then
  echo -e "\n✅ Success! Category created with ID: $CATEGORY_ID"
  echo "Mutation is working correctly!"
else
  echo -e "\n❌ Failed to create category"
  echo "Checking if it's a permission issue or timeout..."
fi
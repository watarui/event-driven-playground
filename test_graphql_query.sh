#!/bin/bash

# テスト用の設定
EMAIL="test-pubsub@example.com"
PASSWORD="TestPubSub123!"
FIREBASE_API_KEY="AIzaSyD9mDKsGQ9f3jcaSJiRrF8_DtUL6t0sG7M"
GRAPHQL_URL="https://client-service-yfmozh2e7a-an.a.run.app/graphql"

echo "=== Testing GraphQL Query API with Google Cloud Pub/Sub ==="

# 1. Firebase 認証
echo -e "\n1. Authenticating with Firebase..."
AUTH_RESPONSE=$(curl -s -X POST "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"${EMAIL}\",
    \"password\": \"${PASSWORD}\",
    \"returnSecureToken\": true
  }")

# アカウントが存在しない場合は作成
if [[ ! "$AUTH_RESPONSE" =~ "idToken" ]]; then
  echo "Creating new account..."
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

# 2. カテゴリ一覧を取得（認証なしでも動作するクエリ）
echo -e "\n2. Fetching categories list via GraphQL query..."
LIST_RESPONSE=$(curl -s -X POST "$GRAPHQL_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ID_TOKEN" \
  -d '{
    "query": "query { categories { id name description } }"
  }')

echo "Categories list response:"
echo "$LIST_RESPONSE" | python3 -m json.tool

# エラーチェック
if [[ "$LIST_RESPONSE" =~ "errors" ]]; then
  echo -e "\n❌ Query failed"
  echo "Please check Cloud Run logs for details"
else
  echo -e "\n✅ Query successful!"
  echo "Google Cloud Pub/Sub query handling is working correctly!"
fi

# 3. ヘルスチェックエンドポイントのテスト
echo -e "\n3. Testing health check endpoint..."
HEALTH_RESPONSE=$(curl -s -X GET "https://client-service-yfmozh2e7a-an.a.run.app/health")
echo "Health check response:"
echo "$HEALTH_RESPONSE" | python3 -m json.tool
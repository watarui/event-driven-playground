#!/bin/bash

# このスクリプトを実行する前に：
# 1. ブラウザでログイン
# 2. 開発者ツール（F12）を開く
# 3. Console タブで以下を実行して ID トークンを取得：
#    firebase.auth().currentUser.getIdToken().then(token => console.log(token))
# 4. 表示されたトークンを下の ID_TOKEN に設定

ID_TOKEN="ここに実際のトークンを貼り付け"
GRAPHQL_URL="https://client-service-yfmozh2e7a-an.a.run.app/graphql"

echo "=== Testing GraphQL Mutation with Current Token ==="

# カテゴリ作成 mutation テスト
echo -e "\nCreating category via GraphQL mutation..."
curl -X POST "$GRAPHQL_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ID_TOKEN" \
  -d '{
    "query": "mutation CreateCategory($input: CreateCategoryInput!) { createCategory(input: $input) { id name description } }",
    "variables": {
      "input": {
        "name": "Test Category with Auth",
        "description": "Testing with authentication token"
      }
    }
  }' | python3 -m json.tool
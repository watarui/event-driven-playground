#!/bin/bash
set -e

# Frontend Vercel デプロイスクリプト
echo "🚀 Frontend Vercel デプロイスクリプト"
echo "===================================="

# バックエンドサービスの URL を取得
echo "📡 バックエンドサービスの URL を取得中..."
CLIENT_SERVICE_URL="https://client-service-741925348867.asia-northeast1.run.app"
echo "Client Service URL: $CLIENT_SERVICE_URL"

# 必要な環境変数のチェック
echo ""
echo "🔍 環境変数のチェック..."
REQUIRED_VARS=(
  "NEXT_PUBLIC_FIREBASE_API_KEY"
  "NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN"
  "NEXT_PUBLIC_FIREBASE_PROJECT_ID"
  "NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET"
  "NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID"
  "NEXT_PUBLIC_FIREBASE_APP_ID"
  "FIREBASE_PROJECT_ID"
  "FIREBASE_CLIENT_EMAIL"
  "FIREBASE_PRIVATE_KEY"
  "INITIAL_ADMIN_EMAIL"
)

# .env.production ファイルが存在するか確認
if [ -f "frontend/.env.production" ]; then
  echo "✅ .env.production ファイルが見つかりました"
else
  echo "❌ frontend/.env.production ファイルが見つかりません"
  echo "frontend/.env.production.example をコピーして設定してください"
  exit 1
fi

# Vercel CLI のインストール確認
if ! command -v vercel &> /dev/null; then
  echo ""
  echo "📦 Vercel CLI をインストール中..."
  bun add -g vercel
fi

# frontend ディレクトリに移動
cd frontend

# Vercel プロジェクトのリンク確認
if [ ! -d ".vercel" ]; then
  echo ""
  echo "🔗 Vercel プロジェクトをリンク中..."
  vercel link
fi

# 環境変数の設定
echo ""
echo "⚙️ 環境変数を設定中..."

# WebSocket エンドポイントを自動設定
echo "NEXT_PUBLIC_WS_ENDPOINT=wss://${CLIENT_SERVICE_URL#https://}/socket/websocket" | vercel env add NEXT_PUBLIC_WS_ENDPOINT production

# GraphQL エンドポイント（API Routes 経由なので設定不要）
# echo "NEXT_PUBLIC_GRAPHQL_ENDPOINT は API Routes 経由のため設定不要"

# その他の環境変数を .env.production から読み込んで設定
echo ""
echo "📝 .env.production から環境変数を設定中..."
echo "※ Firebase の秘密鍵など、機密情報は手動で設定が必要な場合があります"

# デプロイ実行
echo ""
echo "🚀 Vercel にデプロイ中..."
vercel --prod

echo ""
echo "✅ デプロイが完了しました！"
echo ""
echo "📋 次のステップ:"
echo "1. Vercel ダッシュボードで環境変数が正しく設定されているか確認"
echo "2. Firebase Console で Vercel のドメインを承認済みドメインに追加"
echo "3. デプロイされた URL にアクセスして動作確認"
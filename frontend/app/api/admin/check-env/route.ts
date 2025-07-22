import { type NextRequest, NextResponse } from "next/server"
import { config } from "@/lib/config"

// 環境変数の状態を確認するエンドポイント（開発・デバッグ用）
export async function GET(request: NextRequest) {
  // 本番環境では無効化
  if (config.env.isProduction) {
    return NextResponse.json({ error: "Not available in production" }, { status: 403 })
  }

  const envStatus = {
    environment: {
      isDevelopment: config.env.isDevelopment,
      isProduction: config.env.isProduction,
      nodeEnv: process.env.NODE_ENV,
    },
    firebase: {
      // クライアント側の設定
      publicApiKey: !!process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
      publicAuthDomain: !!process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
      publicProjectId: !!process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
      publicStorageBucket: !!process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
      publicMessagingSenderId: !!process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
      publicAppId: !!process.env.NEXT_PUBLIC_FIREBASE_APP_ID,

      // サーバー側の設定（Admin SDK）
      projectId: !!process.env.FIREBASE_PROJECT_ID,
      clientEmail: !!process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: !!process.env.FIREBASE_PRIVATE_KEY,
    },
    auth: {
      initialAdminEmail: process.env.INITIAL_ADMIN_EMAIL || "(not set)",
    },
    vercel: {
      env: process.env.VERCEL_ENV,
      url: process.env.VERCEL_URL,
    },
  }

  return NextResponse.json(envStatus)
}

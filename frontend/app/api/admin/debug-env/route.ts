import { NextResponse } from "next/server"

// 一時的なデバッグエンドポイント（本番環境でも動作）
export async function GET() {
  // 環境変数の状態を返す（機密情報は除外）
  return NextResponse.json({
    NODE_ENV: process.env.NODE_ENV,
    VERCEL_ENV: process.env.VERCEL_ENV,
    hasInitialAdminEmail: !!process.env.INITIAL_ADMIN_EMAIL,
    // 実際の値は返さない（セキュリティのため）
    initialAdminEmailLength: process.env.INITIAL_ADMIN_EMAIL?.length || 0,
    isProduction: process.env.NODE_ENV === "production",
    timestamp: new Date().toISOString(),
  })
}
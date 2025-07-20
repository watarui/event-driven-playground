import { NextResponse } from "next/server"
import { getAdminAuth } from "@/lib/server/firebase-admin"

// 管理者が存在するかどうかをチェックするエンドポイント
// 認証不要（誰でもアクセス可能）
export async function GET() {
  try {
    const adminAuth = await getAdminAuth()

    // 全ユーザーをリストアップして管理者の存在を確認
    // 大規模なユーザーベースの場合、ページネーションが必要になる可能性があるが、
    // 初期段階では1000ユーザーまでのチェックで十分
    let adminExists = false
    let nextPageToken: string | undefined

    do {
      const listResult = await adminAuth.listUsers(1000, nextPageToken)
      if (listResult.users.some((user) => user.customClaims?.role === "admin")) {
        adminExists = true
        break
      }
      nextPageToken = listResult.pageToken
    } while (nextPageToken)

    return NextResponse.json({
      adminExists,
      timestamp: new Date().toISOString(),
    })
  } catch (error) {
    console.error("Error checking admin existence:", error)
    // エラーの詳細をログに記録
    if (error instanceof Error) {
      console.error("Error details:", {
        message: error.message,
        stack: error.stack,
      })
    }
    
    return NextResponse.json(
      {
        error: "Failed to check admin existence",
        adminExists: null,
        details: process.env.NODE_ENV === "development" ? error instanceof Error ? error.message : String(error) : undefined,
      },
      { status: 500 }
    )
  }
}

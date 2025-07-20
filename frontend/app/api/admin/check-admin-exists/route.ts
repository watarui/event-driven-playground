import { NextResponse } from "next/server"
import { adminAuth } from "@/lib/firebase-admin"

// 管理者が存在するかどうかをチェックするエンドポイント
// 認証不要（誰でもアクセス可能）
export async function GET() {
  try {
    // 全ユーザーをリストアップして管理者の存在を確認
    const allUsers = await adminAuth.listUsers()
    const adminExists = allUsers.users.some((user) => user.customClaims?.role === "admin")

    return NextResponse.json({
      adminExists,
      timestamp: new Date().toISOString(),
    })
  } catch (error) {
    console.error("Error checking admin existence:", error)
    return NextResponse.json(
      {
        error: "Failed to check admin existence",
        adminExists: null,
      },
      { status: 500 }
    )
  }
}

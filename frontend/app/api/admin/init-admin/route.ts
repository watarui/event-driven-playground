import { type NextRequest, NextResponse } from "next/server"
import { config } from "@/lib/config"
import { getAdminAuth, setUserRole } from "@/lib/server/firebase-admin"

// 初回管理者設定用のエンドポイント
// 管理者が一人もいない場合のみ、自分自身を管理者に設定できる
export async function POST(request: NextRequest) {
  console.log("[init-admin] Request received")

  try {
    // 認証トークンを検証
    const authHeader = request.headers.get("authorization")
    if (!authHeader?.startsWith("Bearer ")) {
      console.log("[init-admin] No authorization token provided")
      return NextResponse.json(
        { success: false, message: "No authorization token provided" },
        { status: 401 }
      )
    }

    const token = authHeader.split("Bearer ")[1]
    console.log("[init-admin] Initializing Firebase Admin...")
    const adminAuth = await getAdminAuth()

    // トークンを検証して現在のユーザー情報を取得
    console.log("[init-admin] Verifying ID token...")
    const decodedToken = await adminAuth.verifyIdToken(token)
    const currentUserId = decodedToken.uid
    const currentUserEmail = decodedToken.email
    console.log("[init-admin] Current user:", { uid: currentUserId, email: currentUserEmail })

    // 環境別の設定
    const { isProduction } = config.env
    const initialAdminEmail = config.auth.initialAdminEmail

    // 本番環境では INITIAL_ADMIN_EMAIL が必須
    if (isProduction && !initialAdminEmail) {
      console.log("[init-admin] ERROR: INITIAL_ADMIN_EMAIL not set in production")
      return NextResponse.json(
        {
          success: false,
          message: "Initial admin email not configured for production environment",
        },
        { status: 500 }
      )
    }
    console.log("[init-admin] Environment:", { isProduction, initialAdminEmail })

    // すでに管理者が存在するかチェック
    console.log("[init-admin] Checking for existing admins...")
    const allUsers = await adminAuth.listUsers()
    const adminExists = allUsers.users.some((user) => user.customClaims?.role === "admin")
    console.log("[init-admin] Admin exists:", adminExists)

    if (adminExists) {
      return NextResponse.json(
        {
          success: false,
          message: "Admin already exists. Please contact existing admin to grant permissions.",
        },
        { status: 403 }
      )
    }

    // 本番環境では指定されたメールアドレスのみ管理者になれる
    if (isProduction && currentUserEmail !== initialAdminEmail) {
      console.log("[init-admin] User not authorized:", { currentUserEmail, initialAdminEmail })
      return NextResponse.json(
        {
          success: false,
          message: "You are not authorized to become the initial admin",
        },
        { status: 403 }
      )
    }

    // 管理者が存在しない場合、現在のユーザーを管理者に設定
    console.log("[init-admin] Setting user as admin...")
    await setUserRole(currentUserId, "admin")
    console.log("[init-admin] Admin role set successfully")

    // カスタムクレームが設定されたことを確認
    const updatedUser = await adminAuth.getUser(currentUserId)
    console.log("[init-admin] Updated user claims:", updatedUser.customClaims)

    return NextResponse.json({
      success: true,
      message: `Successfully set ${currentUserEmail} as admin`,
      requiresTokenRefresh: true,
      debug: config.env.isDevelopment
        ? {
            uid: currentUserId,
            email: currentUserEmail,
            customClaims: updatedUser.customClaims,
          }
        : undefined,
    })
  } catch (error) {
    console.error("[init-admin] Error:", error)
    const errorMessage = error instanceof Error ? error.message : "Unknown error"
    return NextResponse.json(
      {
        success: false,
        message: "Internal server error",
        error: config.env.isDevelopment ? errorMessage : undefined,
      },
      { status: 500 }
    )
  }
}

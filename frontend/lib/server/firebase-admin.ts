// ユーザーロールの型定義
export type UserRole = "admin" | "writer" | "viewer"

/**
 * Firebase Admin Auth インスタンスを取得
 * 動的インポートを使用してビルド時のエラーを回避
 */
export async function getAdminAuth() {
  const { initializeApp, getApps, cert } = await import("firebase-admin/app")
  const { getAuth } = await import("firebase-admin/auth")

  if (!getApps().length) {
    const projectId = process.env.FIREBASE_PROJECT_ID
    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL
    const privateKey = process.env.FIREBASE_PRIVATE_KEY

    if (!projectId || !clientEmail || !privateKey) {
      throw new Error("Firebase Admin credentials are not configured")
    }

    initializeApp({
      credential: cert({
        projectId,
        clientEmail,
        privateKey: privateKey.replace(/\\n/g, "\n"),
      }),
    })
  }

  return getAuth()
}

/**
 * ユーザーのカスタムクレームを設定
 */
export async function setUserRole(uid: string, role: UserRole) {
  const auth = await getAdminAuth()
  await auth.setCustomUserClaims(uid, { role })
}

/**
 * ユーザーのカスタムクレームを取得
 */
export async function getUserRole(uid: string): Promise<UserRole | null> {
  try {
    const auth = await getAdminAuth()
    const user = await auth.getUser(uid)
    return user.customClaims?.role || null
  } catch (error) {
    console.error("Error getting user role:", error)
    return null
  }
}

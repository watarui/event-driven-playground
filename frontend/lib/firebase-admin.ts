import { cert, getApps, initializeApp } from "firebase-admin/app"
import { getAuth } from "firebase-admin/auth"

// Firebase Admin SDK の初期化
if (!getApps().length) {
  initializeApp({
    credential: cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, "\n"),
    }),
  })
}

const adminAuth = getAuth()

// ユーザーロールの型定義
export type UserRole = "admin" | "writer" | "viewer"

// ユーザーのカスタムクレームを設定
export async function setUserRole(uid: string, role: UserRole) {
  await adminAuth.setCustomUserClaims(uid, { role })
}

// ユーザーのカスタムクレームを取得
export async function getUserRole(uid: string): Promise<UserRole | null> {
  try {
    const user = await adminAuth.getUser(uid)
    return user.customClaims?.role || null
  } catch (error) {
    console.error("Error getting user role:", error)
    return null
  }
}

export { adminAuth }

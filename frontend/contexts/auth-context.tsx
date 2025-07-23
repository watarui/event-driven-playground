"use client"

import {
  signOut as firebaseSignOut,
  getIdTokenResult,
  onAuthStateChanged,
  signInWithPopup,
  type User,
} from "firebase/auth"
import { createContext, useContext, useEffect, useState } from "react"
import { config } from "@/lib/config"
import { auth, googleProvider } from "@/lib/firebase"
import type { UserRole } from "@/lib/server/firebase-admin"

interface AuthContextType {
  user: User | null
  role: UserRole
  loading: boolean
  signInWithGoogle: () => Promise<void>
  signOut: () => Promise<void>
}

const AuthContext = createContext<AuthContextType | undefined>(undefined)

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [role, setRole] = useState<UserRole>("viewer") // デフォルトは viewer
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      setUser(user)

      if (user) {
        // トークンを強制的にリフレッシュして最新のカスタムクレームを取得
        const tokenResult = await getIdTokenResult(user, true)
        const userRole = tokenResult.claims.role as UserRole | undefined

        if (userRole) {
          // すでにロールが設定されている場合はそれを使用
          setRole(userRole)
        } else {
          // 新規ユーザーの場合はデフォルトで writer
          // 管理者設定は AdminSetupButton から明示的に行う
          setRole("writer")
        }
      } else {
        // 未ログインユーザーは viewer
        setRole("viewer")
      }

      setLoading(false)
    })

    return () => unsubscribe()
  }, [])

  const signInWithGoogle = async () => {
    try {
      await signInWithPopup(auth, googleProvider)
    } catch (error) {
      console.error("Error signing in with Google:", error)
      throw error
    }
  }

  const signOut = async () => {
    try {
      await firebaseSignOut(auth)
    } catch (error) {
      console.error("Error signing out:", error)
      throw error
    }
  }

  return (
    <AuthContext.Provider value={{ user, role, loading, signInWithGoogle, signOut }}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const context = useContext(AuthContext)
  if (context === undefined) {
    throw new Error("useAuth must be used within an AuthProvider")
  }
  return context
}

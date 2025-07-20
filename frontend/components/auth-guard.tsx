"use client"

import { useRouter } from "next/navigation"
import { useEffect } from "react"
import { useAuth } from "@/contexts/auth-context"
import type { UserRole } from "@/lib/firebase-admin"

interface AuthGuardProps {
  children: React.ReactNode
  requireRole?: UserRole | UserRole[]
  fallback?: React.ReactNode
  redirectTo?: string
}

export function AuthGuard({ children, requireRole, fallback, redirectTo }: AuthGuardProps) {
  const { user, role, loading } = useAuth()
  const router = useRouter()

  useEffect(() => {
    if (!loading && requireRole) {
      const requiredRoles = Array.isArray(requireRole) ? requireRole : [requireRole]

      // 権限階層: admin > writer > viewer
      const roleHierarchy: Record<UserRole, number> = {
        viewer: 1,
        writer: 2,
        admin: 3,
      }

      const userLevel = roleHierarchy[role]
      const requiredLevel = Math.min(...requiredRoles.map((r) => roleHierarchy[r]))

      if (userLevel < requiredLevel) {
        if (redirectTo) {
          router.push(redirectTo)
        } else if (role === "viewer" && requiredRoles.includes("writer")) {
          // viewer が writer 権限を必要とする場合は unauthorized ページへ
          router.push("/unauthorized")
        } else {
          // その他の権限不足は unauthorized ページへ
          router.push("/unauthorized")
        }
      }
    }
  }, [user, role, loading, requireRole, router, redirectTo])

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-gray-900 dark:border-white mx-auto"></div>
          <p className="mt-4 text-gray-600 dark:text-gray-400">Loading...</p>
        </div>
      </div>
    )
  }

  // 権限チェック
  if (requireRole) {
    const requiredRoles = Array.isArray(requireRole) ? requireRole : [requireRole]
    const roleHierarchy: Record<UserRole, number> = {
      viewer: 1,
      writer: 2,
      admin: 3,
    }

    const userLevel = roleHierarchy[role]
    const requiredLevel = Math.min(...requiredRoles.map((r) => roleHierarchy[r]))

    if (userLevel < requiredLevel) {
      return fallback || null
    }
  }

  return <>{children}</>
}

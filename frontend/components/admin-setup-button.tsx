"use client"

import { AlertCircle, CheckCircle, Shield } from "lucide-react"
import { useEffect, useState } from "react"
import { useAuth } from "@/contexts/auth-context"

export function AdminSetupButton() {
  const { user, role, loading } = useAuth()
  const [isLoading, setIsLoading] = useState(false)
  const [message, setMessage] = useState<{ type: "success" | "error"; text: string } | null>(null)
  const [adminExists, setAdminExists] = useState<boolean | null>(null)
  const [checkingAdmin, setCheckingAdmin] = useState(true)

  // 管理者が存在するかチェック
  useEffect(() => {
    const checkAdminExists = async () => {
      try {
        const response = await fetch("/api/admin/check-admin-exists")
        const data = await response.json()
        setAdminExists(data.adminExists)
      } catch (error) {
        console.error("Failed to check admin existence:", error)
        // エラーの場合は null のままにして、ボタンは表示する
      } finally {
        setCheckingAdmin(false)
      }
    }

    checkAdminExists()
  }, [])

  const handleSetupAdmin = async () => {
    if (!user) return

    setIsLoading(true)
    setMessage(null)

    try {
      const token = await user.getIdToken()
      const response = await fetch("/api/admin/init-admin", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
      })

      const data = await response.json()

      if (response.ok) {
        setMessage({ type: "success", text: data.message })
        // トークンをリフレッシュして新しいロールを反映
        if (data.requiresTokenRefresh) {
          await user.getIdToken(true)
          window.location.reload()
        }
      } else {
        setMessage({ type: "error", text: data.message })
      }
    } catch (_error) {
      setMessage({ type: "error", text: "Failed to setup admin role" })
    } finally {
      setIsLoading(false)
    }
  }

  // 表示条件:
  // 1. ローディング中でない
  // 2. 現在のユーザーが管理者でない
  // 3. 管理者存在チェック中でない
  // 4. システムに管理者が存在しない（またはチェックエラー）
  if (loading || checkingAdmin || role === "admin" || adminExists === true) {
    return null
  }

  return (
    <div className="p-4 bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded-lg">
      <div className="flex items-start gap-3">
        <AlertCircle className="w-5 h-5 text-yellow-600 dark:text-yellow-400 mt-0.5" />
        <div className="flex-1">
          <h3 className="font-semibold text-yellow-800 dark:text-yellow-200">
            管理者権限の初期設定
          </h3>
          <p className="text-sm text-yellow-700 dark:text-yellow-300 mt-1">
            まだ管理者が設定されていません。最初のユーザーとして管理者権限を取得できます。
          </p>

          <button
            type="button"
            onClick={handleSetupAdmin}
            disabled={isLoading}
            className="mt-3 flex items-center gap-2 px-4 py-2 bg-yellow-600 hover:bg-yellow-700 disabled:bg-yellow-500 text-white rounded-md transition-colors text-sm font-medium"
          >
            <Shield className="w-4 h-4" />
            {isLoading ? "設定中..." : "管理者として設定"}
          </button>

          {message && (
            <div
              className={`mt-3 flex items-start gap-2 text-sm ${
                message.type === "success"
                  ? "text-green-700 dark:text-green-300"
                  : "text-red-700 dark:text-red-300"
              }`}
            >
              {message.type === "success" ? (
                <CheckCircle className="w-4 h-4 mt-0.5" />
              ) : (
                <AlertCircle className="w-4 h-4 mt-0.5" />
              )}
              <span>{message.text}</span>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

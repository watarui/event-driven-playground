"use client"

import { AlertCircle, CheckCircle, Shield } from "lucide-react"
import { useEffect, useState } from "react"
import { useAuth } from "@/contexts/auth-context"
import { config } from "@/lib/config"

export function AdminSetupButton() {
  const { user, role, loading } = useAuth()
  const [isLoading, setIsLoading] = useState(false)
  const [message, setMessage] = useState<{
    type: "success" | "error"
    text: string
  } | null>(null)
  const [adminExists, setAdminExists] = useState<boolean | null>(null)
  const [checkingAdmin, setCheckingAdmin] = useState(true)

  // デバッグ: 環境変数の状態を確認
  useEffect(() => {
    console.log("[AdminSetupButton] Environment check:", {
      isProduction: config.env.isProduction,
      // クライアントサイドでは INITIAL_ADMIN_EMAIL にアクセスできない
      initialAdminEmail: "(not accessible on client side)",
      currentUserEmail: user?.email,
      role,
    })
  }, [user, role])

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
    console.log("[AdminSetupButton] handleSetupAdmin called", {
      user: user?.email,
      hasUser: !!user,
    })

    if (!user) {
      console.error("[AdminSetupButton] No user logged in")
      setMessage({
        type: "error",
        text: "ログインが必要です",
      })
      return
    }

    setIsLoading(true)
    setMessage(null)

    try {
      console.log("[AdminSetupButton] Getting ID token...")
      const token = await user.getIdToken()
      console.log("[AdminSetupButton] Sending request to /api/admin/init-admin")

      const response = await fetch("/api/admin/init-admin", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
      })

      const data = await response.json()

      if (response.ok) {
        setMessage({
          type: "success",
          text: data.message || "管理者権限を設定しました。ページを再読み込みします...",
        })
        // Firebase カスタムクレームの反映のため、必ずページをリロード
        setTimeout(() => {
          window.location.reload()
        }, 1000)
      } else {
        console.error("Admin setup failed:", {
          status: response.status,
          statusText: response.statusText,
          data,
        })
        // エラーメッセージをより分かりやすく
        let errorMessage = data.message || `管理者設定に失敗しました (${response.status})`

        // 特定のエラーケースに対して追加情報を提供
        if (response.status === 403 && data.adminExists) {
          errorMessage += "\n\n管理者が既に存在します。既存の管理者に権限付与を依頼してください。"
        }

        setMessage({
          type: "error",
          text: errorMessage,
        })
      }
    } catch (error) {
      console.error("Admin setup error:", error)
      setMessage({
        type: "error",
        text: error instanceof Error ? error.message : "Failed to setup admin role",
      })
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
            まだ管理者が設定されていません。
            {config.env.isProduction ? (
              <>
                <br />
                <strong>注意:</strong>{" "}
                本番環境では事前に指定されたメールアドレスのみが管理者になれます。
              </>
            ) : (
              "最初のユーザーとして管理者権限を取得できます。"
            )}
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
                <CheckCircle className="w-4 h-4 mt-0.5 flex-shrink-0" />
              ) : (
                <AlertCircle className="w-4 h-4 mt-0.5 flex-shrink-0" />
              )}
              <span className="whitespace-pre-wrap">{message.text}</span>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

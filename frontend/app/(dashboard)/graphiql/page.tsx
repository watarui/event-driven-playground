"use client"

import { RefreshCw, Shield, ShieldAlert } from "lucide-react"
import { useEffect, useRef, useState } from "react"
import { AdminSetupButton } from "@/components/admin-setup-button"
import { useAuth } from "@/contexts/auth-context"

export default function GraphiQLPage() {
  const { user, role, loading } = useAuth()
  const iframeRef = useRef<HTMLIFrameElement>(null)
  const [isIframeLoading, setIsIframeLoading] = useState(true)

  // iframe がロードされたらローディング状態を解除
  const handleIframeLoad = () => {
    setIsIframeLoading(false)
  }

  // トークンが更新されたら iframe に通知
  const refreshToken = async () => {
    if (user) {
      try {
        const newToken = await user.getIdToken(true)
        // Cookie に新しいトークンを設定
        document.cookie = `auth-token=${newToken}; path=/; samesite=strict`
        // iframe に更新を通知
        if (iframeRef.current) {
          iframeRef.current.contentWindow?.postMessage(
            { type: "AUTH_TOKEN_UPDATED" },
            window.location.origin
          )
        }
      } catch (error) {
        console.error("Failed to refresh token:", error)
      }
    }
  }

  // 認証情報が変更されたら Cookie を更新
  useEffect(() => {
    const updateAuthCookie = async () => {
      if (user) {
        try {
          const token = await user.getIdToken()
          document.cookie = `auth-token=${token}; path=/; samesite=strict`
        } catch (error) {
          console.error("Failed to set auth cookie:", error)
        }
      } else {
        // ユーザーがログアウトした場合は Cookie を削除
        document.cookie = "auth-token=; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT"
      }
    }
    updateAuthCookie()
  }, [user])

  if (loading) {
    return (
      <div className="flex items-center justify-center h-screen">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-gray-900 dark:border-white mx-auto"></div>
          <p className="mt-4 text-gray-600 dark:text-gray-400">Loading...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="h-[calc(100vh-4rem)] md:h-screen -m-8 flex flex-col">
      {/* ヘッダー */}
      <div className="bg-white dark:bg-gray-900 border-b border-gray-200 dark:border-gray-800 px-4 py-3 flex items-center justify-between">
        <div className="flex items-center gap-4">
          <h1 className="text-lg font-semibold">GraphQL Explorer</h1>
          <div className="flex items-center gap-2">
            {role === "admin" ? (
              <span className="flex items-center gap-1 px-2 py-1 rounded-full bg-green-100 dark:bg-green-900 text-green-800 dark:text-green-200 text-xs font-medium">
                <Shield className="w-3 h-3" />
                Admin Access
              </span>
            ) : role === "writer" ? (
              <span className="flex items-center gap-1 px-2 py-1 rounded-full bg-blue-100 dark:bg-blue-900 text-blue-800 dark:text-blue-200 text-xs font-medium">
                <Shield className="w-3 h-3" />
                Writer Access
              </span>
            ) : (
              <span className="flex items-center gap-1 px-2 py-1 rounded-full bg-yellow-100 dark:bg-yellow-900 text-yellow-800 dark:text-yellow-200 text-xs font-medium">
                <ShieldAlert className="w-3 h-3" />
                Viewer (Read-only)
              </span>
            )}
          </div>
        </div>

        <div className="flex items-center gap-2 text-sm">
          <span className="text-gray-600 dark:text-gray-400">{user?.email}</span>
          <button
            type="button"
            onClick={refreshToken}
            className="flex items-center gap-1 px-2 py-1 rounded hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
            title="Refresh authentication token"
          >
            <RefreshCw className="w-4 h-4" />
            <span>Refresh</span>
          </button>
        </div>
      </div>

      {/* 権限に関する情報表示 */}
      {/* 管理者設定ボタンは viewer または writer の時に表示 */}
      {(role === "viewer" || role === "writer") && (
        <div className="p-4">
          <AdminSetupButton />
        </div>
      )}

      {/* Viewer ロールの警告 */}
      {role === "viewer" && (
        <div className="bg-yellow-50 dark:bg-yellow-900/20 px-4 py-2 text-sm border-b border-yellow-200 dark:border-yellow-800">
          <span className="text-yellow-800 dark:text-yellow-200">
            ⚠️ Viewer ロールではクエリのみ実行可能です。Mutation の実行には Writer または Admin
            権限が必要です。
          </span>
        </div>
      )}

      {/* GraphiQL iframe */}
      <div className="flex-1 relative">
        {isIframeLoading && (
          <div className="absolute inset-0 flex items-center justify-center bg-gray-50 dark:bg-gray-900">
            <div className="text-center">
              <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-gray-900 dark:border-white mx-auto"></div>
              <p className="mt-4 text-gray-600 dark:text-gray-400">Loading GraphiQL...</p>
            </div>
          </div>
        )}
        <iframe
          ref={iframeRef}
          src="/api/graphiql-standalone"
          className="w-full h-full border-0"
          onLoad={handleIframeLoad}
          title="GraphiQL Explorer"
        />
      </div>
    </div>
  )
}

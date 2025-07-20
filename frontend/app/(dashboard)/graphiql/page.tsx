"use client"

import { useEffect, useRef, useState } from 'react'
import { useAuth } from '@/contexts/auth-context'
import { AdminSetupButton } from '@/components/admin-setup-button'
import { Shield, ShieldAlert, RefreshCw } from 'lucide-react'

export default function GraphiQLPage() {
  const { user, role, loading } = useAuth()
  const iframeRef = useRef<HTMLIFrameElement>(null)
  const [isIframeLoading, setIsIframeLoading] = useState(true)
  const [token, setToken] = useState<string | null>(null)

  // Firebase トークンを取得
  useEffect(() => {
    const getToken = async () => {
      if (user) {
        const idToken = await user.getIdToken()
        setToken(idToken)
      }
    }
    getToken()
  }, [user])

  // iframe がロードされたら認証情報を送信
  const handleIframeLoad = () => {
    setIsIframeLoading(false)
    if (iframeRef.current && token) {
      // postMessage でトークンを送信
      iframeRef.current.contentWindow?.postMessage(
        {
          type: 'AUTH_TOKEN',
          token: token,
          role: role
        },
        window.location.origin
      )
    }
  }

  // トークンが更新されたら iframe に再送信
  useEffect(() => {
    if (!isIframeLoading && iframeRef.current && token) {
      iframeRef.current.contentWindow?.postMessage(
        {
          type: 'AUTH_TOKEN',
          token: token,
          role: role
        },
        window.location.origin
      )
    }
  }, [token, role, isIframeLoading])

  const refreshToken = async () => {
    if (user) {
      const newToken = await user.getIdToken(true)
      setToken(newToken)
    }
  }

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
            {role === 'admin' ? (
              <span className="flex items-center gap-1 px-2 py-1 rounded-full bg-green-100 dark:bg-green-900 text-green-800 dark:text-green-200 text-xs font-medium">
                <Shield className="w-3 h-3" />
                Admin Access
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
          <span className="text-gray-600 dark:text-gray-400">
            {user?.email}
          </span>
          <button
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
      {role === 'viewer' && (
        <>
          <div className="bg-yellow-50 dark:bg-yellow-900/20 px-4 py-2 text-sm border-b border-yellow-200 dark:border-yellow-800">
            <span className="text-yellow-800 dark:text-yellow-200">
              ⚠️ Viewer ロールではクエリのみ実行可能です。Mutation の実行には Writer または Admin 権限が必要です。
            </span>
          </div>
          <div className="p-4">
            <AdminSetupButton />
          </div>
        </>
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
          src={`${process.env.NODE_ENV === 'production' ? 'https://client-service-yfmozh2e7a-an.a.run.app' : 'http://localhost:4000'}/graphiql`}
          className="w-full h-full border-0"
          onLoad={handleIframeLoad}
          title="GraphiQL Explorer"
        />
      </div>
    </div>
  )
}
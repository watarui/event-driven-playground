"use client"

import { GraphiQL } from "graphiql"
import { useEffect, useRef, useState } from "react"
import ReactDOM from "react-dom/client"
import { useAuth } from "@/contexts/auth-context"

// GraphiQL の CSS を文字列として定義（CDN から取得）
const GRAPHIQL_CSS_URL = "https://unpkg.com/graphiql@3/graphiql.min.css"

export function GraphiQLShadowContainer() {
  const containerRef = useRef<HTMLDivElement>(null)
  const shadowRootRef = useRef<ShadowRoot | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [cssLoaded, setCssLoaded] = useState(false)
  const [graphiqlCSS, setGraphiqlCSS] = useState("")
  const { user, role } = useAuth()

  // GraphiQL の CSS を取得
  useEffect(() => {
    fetch(GRAPHIQL_CSS_URL)
      .then((res) => res.text())
      .then((css) => {
        setGraphiqlCSS(css)
        setCssLoaded(true)
      })
      .catch((err) => {
        console.error("Failed to load GraphiQL CSS:", err)
        setCssLoaded(true) // エラーでも続行
      })
  }, [])

  // Shadow DOM の作成と GraphiQL のマウント
  useEffect(() => {
    if (!containerRef.current || !cssLoaded) return

    // Shadow DOM を作成
    if (!shadowRootRef.current) {
      shadowRootRef.current = containerRef.current.attachShadow({ mode: "open" })
    }

    const shadowRoot = shadowRootRef.current

    // Shadow DOM 内に HTML 構造を作成
    shadowRoot.innerHTML = `
      <style>
        :host {
          display: block;
          width: 100%;
          height: 100%;
        }
        #graphiql-root {
          width: 100%;
          height: 100%;
        }
        /* GraphiQL CSS */
        ${graphiqlCSS}
        
        /* ダークモード対応 */
        ${
          document.documentElement.classList.contains("dark")
            ? `
          .graphiql-container {
            background-color: #1f2937;
            color: #f3f4f6;
          }
          .graphiql-editor {
            background-color: #111827;
          }
          .CodeMirror {
            background-color: #111827;
            color: #f3f4f6;
          }
          .CodeMirror-gutters {
            background-color: #1f2937;
            border-right-color: #374151;
          }
        `
            : ""
        }
      </style>
      <div id="graphiql-root"></div>
    `

    // GraphiQL をマウント
    const mountPoint = shadowRoot.getElementById("graphiql-root")
    if (!mountPoint) return

    // 認証付き fetcher を作成
    const createAuthenticatedFetcher = () => {
      return async (graphQLParams: any) => {
        const headers: Record<string, string> = {
          "Content-Type": "application/json",
        }

        if (user) {
          try {
            const token = await user.getIdToken()
            headers.Authorization = `Bearer ${token}`
          } catch (error) {
            console.error("Failed to get auth token:", error)
          }
        }

        const response = await fetch("/api/graphql", {
          method: "POST",
          headers,
          body: JSON.stringify(graphQLParams),
        })

        return response.json()
      }
    }

    // React 18 の createRoot を使用
    const root = ReactDOM.createRoot(mountPoint)

    // GraphiQL をレンダリング
    root.render(
      <GraphiQL
        fetcher={createAuthenticatedFetcher()}
        defaultQuery={`# Event Driven Playground GraphQL Explorer
# 
# 認証状態: ${user ? `${role} (${user.email})` : "未認証"}
# 
# ショートカット:
#   Ctrl/Cmd + Enter: クエリを実行
#   Ctrl/Cmd + Space: オートコンプリート
#   Ctrl/Cmd + /: 選択行をコメント化
#
# 例: カテゴリ一覧を取得
query GetCategories {
  categories {
    id
    name
    products {
      id
      name
      price
    }
  }
}`}
      />
    )

    setIsLoading(false)

    // クリーンアップ
    return () => {
      root.unmount()
    }
  }, [cssLoaded, user, role, graphiqlCSS])

  // ダークモード切り替えの監視
  useEffect(() => {
    const observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (
          mutation.type === "attributes" &&
          mutation.attributeName === "class" &&
          shadowRootRef.current
        ) {
          // Shadow DOM 内のスタイルを更新
          const styleElement = shadowRootRef.current.querySelector("style")
          if (styleElement) {
            const isDark = document.documentElement.classList.contains("dark")
            styleElement.textContent = `
              :host {
                display: block;
                width: 100%;
                height: 100%;
              }
              #graphiql-root {
                width: 100%;
                height: 100%;
              }
              /* GraphiQL CSS */
              ${graphiqlCSS}
              
              /* ダークモード対応 */
              ${
                isDark
                  ? `
                .graphiql-container {
                  background-color: #1f2937;
                  color: #f3f4f6;
                }
                .graphiql-editor {
                  background-color: #111827;
                }
                .CodeMirror {
                  background-color: #111827;
                  color: #f3f4f6;
                }
                .CodeMirror-gutters {
                  background-color: #1f2937;
                  border-right-color: #374151;
                }
              `
                  : ""
              }
            `
          }
        }
      })
    })

    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["class"],
    })

    return () => observer.disconnect()
  }, [graphiqlCSS])

  if (!cssLoaded) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-gray-900 dark:border-white mx-auto"></div>
          <p className="mt-4 text-gray-600 dark:text-gray-400">Loading GraphiQL styles...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="relative w-full h-full">
      {isLoading && (
        <div className="absolute inset-0 flex items-center justify-center bg-white dark:bg-gray-900 z-10">
          <div className="text-center">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-gray-900 dark:border-white mx-auto"></div>
            <p className="mt-4 text-gray-600 dark:text-gray-400">Initializing GraphiQL...</p>
          </div>
        </div>
      )}
      <div ref={containerRef} className="w-full h-full" />
    </div>
  )
}

"use client"

import { useState, useEffect } from "react"
import { SidebarNavigation } from "@/components/sidebar-navigation"

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const [isSidebarOpen, setIsSidebarOpen] = useState(false)
  const [isClient, setIsClient] = useState(false)

  useEffect(() => {
    setIsClient(true)
    // localStorage から初期状態を読み込む
    const savedState = localStorage.getItem('sidebarOpen')
    if (savedState !== null) {
      setIsSidebarOpen(savedState === 'true')
    } else {
      // デフォルトではデスクトップで開いた状態、モバイルで閉じた状態
      const isMobile = window.innerWidth < 768
      setIsSidebarOpen(!isMobile)
    }
  }, [])

  // サーバーサイドレンダリング時はデフォルト状態を使用
  const shouldShowMargin = isClient ? isSidebarOpen : true

  return (
    <div className="flex min-h-screen bg-gray-50 dark:bg-gray-900">
      <SidebarNavigation 
        isSidebarOpen={isSidebarOpen} 
        setIsSidebarOpen={setIsSidebarOpen}
      />
      <main className={`flex-1 pt-16 md:pt-0 transition-all duration-300 ${
        shouldShowMargin ? 'md:ml-64' : 'md:ml-0'
      }`}>
        <div className="p-8">
          {children}
        </div>
      </main>
    </div>
  )
}
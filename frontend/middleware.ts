import type { NextRequest } from "next/server"
import { NextResponse } from "next/server"

export function middleware(request: NextRequest) {
  // 静的ファイルと API ルートはスキップ
  if (
    request.nextUrl.pathname.startsWith("/_next") ||
    request.nextUrl.pathname.startsWith("/api") ||
    request.nextUrl.pathname.includes(".")
  ) {
    return NextResponse.next()
  }

  // Firebase Auth のチェックはクライアントサイドで行う
  // middleware ではルーティングのみ制御
  return NextResponse.next()
}

export const config = {
  matcher: "/((?!api|_next/static|_next/image|favicon.ico).*)",
}

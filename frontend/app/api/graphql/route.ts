import { type NextRequest, NextResponse } from "next/server"

const GRAPHQL_ENDPOINT =
  process.env.NEXT_PUBLIC_GRAPHQL_ENDPOINT ||
  "https://client-service-yfmozh2e7a-an.a.run.app/graphql"

export async function POST(request: NextRequest) {
  try {
    const body = await request.text()

    console.log("[GraphQL Proxy] Incoming request body:", body)
    console.log("[GraphQL Proxy] Authorization header:", request.headers.get("authorization"))

    const headers: HeadersInit = {
      "Content-Type": "application/json",
      Accept: "application/json",
      // Forward authorization header if present
      ...(request.headers.get("authorization") && {
        Authorization: request.headers.get("authorization")!,
      }),
    }

    console.log("[GraphQL Proxy] Forwarding to:", GRAPHQL_ENDPOINT)
    console.log("[GraphQL Proxy] Headers:", headers)

    const response = await fetch(GRAPHQL_ENDPOINT, {
      method: "POST",
      headers,
      body,
    })

    const responseText = await response.text()

    console.log("[GraphQL Proxy] Response status:", response.status)
    console.log("[GraphQL Proxy] Response headers:", Object.fromEntries(response.headers.entries()))
    console.log("[GraphQL Proxy] Response body:", responseText)

    // エラーの詳細を確認
    if (!response.ok) {
      console.error("[GraphQL Proxy] Error response:", {
        status: response.status,
        statusText: response.statusText,
        body: responseText,
      })
    }

    return new NextResponse(responseText, {
      status: response.status,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
      },
    })
  } catch (error) {
    console.error("[GraphQL Proxy] Exception caught:", error)
    console.error("[GraphQL Proxy] Error details:", {
      message: error instanceof Error ? error.message : "Unknown error",
      stack: error instanceof Error ? error.stack : undefined,
    })

    return NextResponse.json(
      {
        error: "Internal server error",
        details: error instanceof Error ? error.message : "Unknown error",
      },
      { status: 500 }
    )
  }
}

export async function GET() {
  return NextResponse.json({ error: "Method not allowed" }, { status: 405 })
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
      "Access-Control-Max-Age": "86400",
    },
  })
}

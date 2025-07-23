// 環境変数の設定を一元管理
export const config = {
  // GraphQL エンドポイント
  graphql: {
    httpEndpoint:
      process.env.NODE_ENV === "production"
        ? "/api/graphql" // 本番環境でも API Routes 経由
        : process.env.NEXT_PUBLIC_GRAPHQL_ENDPOINT || "/api/graphql", // 開発環境ではプロキシ経由
    wsEndpoint: process.env.NEXT_PUBLIC_WS_ENDPOINT || "ws://localhost:4000/socket/websocket",
  },

  // メトリクスエンドポイント (GraphQL 経由で取得)
  metrics: {
    endpoint: process.env.NEXT_PUBLIC_GRAPHQL_ENDPOINT || "http://localhost:4000/graphql",
  },

  // その他の設定
  polling: {
    defaultInterval: 5000, // 5秒
    metricsInterval: 10000, // 10秒
  },

  // 認証・権限管理
  auth: {
    // 初期管理者のメールアドレス
    // 開発環境では任意、本番環境では必須
    // サーバーサイドのみで使用されるため、NEXT_PUBLIC_ プレフィックスは不要
    initialAdminEmail: process.env.INITIAL_ADMIN_EMAIL,
  },

  // 環境判定
  env: {
    isDevelopment: process.env.NODE_ENV === "development",
    isProduction: process.env.NODE_ENV === "production",
  },
}

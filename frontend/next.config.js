/** @type {import('next').NextConfig} */
const nextConfig = {
	reactStrictMode: true,
	output: "standalone",
	// バックエンド用の環境変数はフロントエンドでは使用しない

	// API エンドポイントへのプロキシ設定
	async rewrites() {
		// 本番環境では同一ドメインで動作するため、rewrites は不要
		// 開発環境では異なるポートで動作するため、プロキシが必要
		const isDevelopment = process.env.NODE_ENV === "development";

		if (isDevelopment) {
			return [
				{
					source: "/api/graphql",
					destination:
						process.env.NEXT_PUBLIC_GRAPHQL_ENDPOINT ||
						"http://localhost:4000/graphql",
				},
				{
					source: "/api/metrics",
					destination: "http://localhost:4000/metrics",
				},
			];
		}

		return [];
	},
};

module.exports = nextConfig;

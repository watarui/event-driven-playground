import { type NextRequest, NextResponse } from "next/server";
import { getAdminAuth, setUserRole } from "@/lib/server/firebase-admin";

export async function POST(request: NextRequest) {
	try {
		// 認証トークンを検証
		const authHeader = request.headers.get("authorization");
		if (!authHeader?.startsWith("Bearer ")) {
			return NextResponse.json(
				{ success: false, message: "No authorization token provided" },
				{ status: 401 },
			);
		}

		const token = authHeader.split("Bearer ")[1];
		const adminAuth = await getAdminAuth();

		// トークンを検証して現在のユーザー情報を取得
		const decodedToken = await adminAuth.verifyIdToken(token);
		const currentUserRole = decodedToken.customClaims?.role;

		// 現在のユーザーが管理者でない場合は拒否
		if (currentUserRole !== "admin") {
			return NextResponse.json(
				{ success: false, message: "Forbidden: Admin access required" },
				{ status: 403 },
			);
		}

		// リクエストボディから対象ユーザーの情報を取得
		const { uid, role } = await request.json();

		if (!uid || !role) {
			return NextResponse.json(
				{ success: false, message: "Missing required fields: uid and role" },
				{ status: 400 },
			);
		}

		// ロールを設定
		await setUserRole(uid, role);

		return NextResponse.json({
			success: true,
			message: `Role set to ${role} for user ${uid}`,
		});
	} catch (error) {
		console.error("Error setting user role:", error);
		return NextResponse.json(
			{ success: false, message: "Internal server error" },
			{ status: 500 },
		);
	}
}

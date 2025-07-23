"use client";

import { LogIn } from "lucide-react";
import Link from "next/link";
import { useAuth } from "@/contexts/auth-context";

export default function UnauthorizedPage() {
	const { user, role, signInWithGoogle } = useAuth();

	return (
		<div className="min-h-screen flex items-center justify-center bg-gray-50 dark:bg-gray-900">
			<div className="max-w-md w-full space-y-8 text-center">
				<div>
					<h1 className="text-4xl font-bold text-gray-900 dark:text-white">
						403
					</h1>
					<h2 className="mt-6 text-3xl font-extrabold text-gray-900 dark:text-white">
						Access Denied
					</h2>
					<p className="mt-2 text-sm text-gray-600 dark:text-gray-400">
						You don't have permission to access this resource.
					</p>
					{user && (
						<p className="mt-2 text-sm text-gray-600 dark:text-gray-400">
							Your role:{" "}
							<span className="font-semibold">{role || "viewer"}</span>
						</p>
					)}
				</div>
				<div className="space-y-4">
					{!user && (
						<button
							type="button"
							onClick={() => signInWithGoogle()}
							className="inline-flex items-center gap-2 px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 transition-colors"
						>
							<LogIn className="w-4 h-4" />
							<span>ログイン</span>
						</button>
					)}
					<Link
						href="/"
						className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors"
					>
						Go back to dashboard
					</Link>
				</div>
			</div>
		</div>
	);
}

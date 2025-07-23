"use client";

import {
	Activity,
	ChevronRight,
	Command,
	Database,
	Heart,
	Home,
	LogIn,
	LogOut,
	Menu,
	Moon,
	Network,
	Radio,
	Sun,
	User,
	X,
} from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { useAuth } from "@/contexts/auth-context";

interface NavItem {
	name: string;
	href: string;
	icon: React.ElementType;
	adminOnly?: boolean;
	external?: boolean;
	children?: NavItem[];
}

const navItems: NavItem[] = [
	{ name: "Dashboard", href: "/", icon: Home },
	{ name: "Events", href: "/events", icon: Activity },
	{ name: "Commands", href: "/commands", icon: Command },
	{ name: "Queries", href: "/queries", icon: Database },
	{ name: "Sagas", href: "/sagas", icon: Radio },
	{ name: "PubSub", href: "/pubsub", icon: Radio },
	{ name: "Health", href: "/health", icon: Heart },
	{ name: "Topology", href: "/topology", icon: Network },
	{ name: "GraphQL", href: "/graphiql", icon: Database },
];

interface SidebarNavigationProps {
	isSidebarOpen: boolean;
	setIsSidebarOpen: (open: boolean) => void;
}

export function SidebarNavigation({
	isSidebarOpen,
	setIsSidebarOpen,
}: SidebarNavigationProps) {
	const pathname = usePathname();
	const { user, role, loading, signOut, signInWithGoogle } = useAuth();
	const [isDarkMode, setIsDarkMode] = useState<boolean>(true);

	// モバイルかどうかを判定する関数
	const isMobile = () => {
		if (typeof window !== "undefined") {
			return window.innerWidth < 768;
		}
		return false;
	};

	useEffect(() => {
		// 初回マウント時にダークモードの状態を確認
		const isDark = document.documentElement.classList.contains("dark");
		setIsDarkMode(isDark);

		// システム設定がダークモードの場合、クラスを追加
		if (
			window.matchMedia?.("(prefers-color-scheme: dark)").matches &&
			!isDark
		) {
			document.documentElement.classList.add("dark");
			setIsDarkMode(true);
		}
	}, []);

	const toggleDarkMode = () => {
		const newMode = !isDarkMode;
		setIsDarkMode(newMode);
		if (newMode) {
			document.documentElement.classList.add("dark");
		} else {
			document.documentElement.classList.remove("dark");
		}
	};

	const toggleSidebar = () => {
		const newState = !isSidebarOpen;
		setIsSidebarOpen(newState);
		// localStorage に保存
		if (typeof window !== "undefined") {
			localStorage.setItem("sidebarOpen", newState.toString());
		}
	};

	const filteredNavItems = navItems.filter(
		(item) => !item.adminOnly || (item.adminOnly && role === "admin"),
	);

	return (
		<>
			{/* モバイル用ハンバーガーメニュー */}
			<div className="fixed top-0 left-0 right-0 z-50 bg-white dark:bg-gray-900 border-b border-gray-200 dark:border-gray-800 md:hidden">
				<div className="flex items-center justify-between h-16 px-4">
					<button
						type="button"
						onClick={toggleSidebar}
						className="p-2 rounded-md hover:bg-gray-200 dark:hover:bg-gray-700"
					>
						{isSidebarOpen ? (
							<X className="w-6 h-6" />
						) : (
							<Menu className="w-6 h-6" />
						)}
					</button>
					<h1 className="text-xl font-bold">CQRS/ES Monitor</h1>
					<button
						type="button"
						onClick={toggleDarkMode}
						className="p-2 rounded-md hover:bg-gray-200 dark:hover:bg-gray-700"
					>
						{isDarkMode ? (
							<Sun className="w-5 h-5" />
						) : (
							<Moon className="w-5 h-5" />
						)}
					</button>
				</div>
			</div>

			{/* サイドバー */}
			<div
				className={`fixed inset-y-0 left-0 z-40 w-64 bg-white dark:bg-gray-900 border-r border-gray-200 dark:border-gray-800 transform transition-transform duration-300 ease-in-out ${
					isSidebarOpen ? "translate-x-0" : "-translate-x-full"
				}`}
			>
				<div className="flex flex-col h-screen">
					{/* ヘッダー */}
					<div className="hidden md:flex items-center justify-between h-16 px-6 border-b border-gray-200 dark:border-gray-800">
						<h1 className="text-xl font-bold">CQRS/ES Monitor</h1>
						<div className="flex items-center gap-2">
							<button
								type="button"
								onClick={toggleDarkMode}
								className="p-2 rounded-md hover:bg-gray-200 dark:hover:bg-gray-700"
								title="Toggle dark mode"
							>
								{isDarkMode ? (
									<Sun className="w-5 h-5" />
								) : (
									<Moon className="w-5 h-5" />
								)}
							</button>
							<button
								type="button"
								onClick={toggleSidebar}
								className="p-2 rounded-md hover:bg-gray-200 dark:hover:bg-gray-700"
								title="Close sidebar"
							>
								<ChevronRight className="w-5 h-5 rotate-180" />
							</button>
						</div>
					</div>

					{/* ナビゲーションメニュー */}
					<nav className="flex-1 overflow-y-auto p-4">
						<div className="space-y-1">
							{filteredNavItems.map((item) => {
								const Icon = item.icon;
								const isActive = pathname === item.href;

								if (item.external) {
									return (
										<a
											key={item.name}
											href={item.href}
											target="_blank"
											rel="noopener noreferrer"
											onClick={() => {
												// モバイルの場合のみサイドバーを閉じる
												if (isMobile()) {
													setIsSidebarOpen(false);
												}
											}}
											className={`flex items-center gap-3 px-3 py-2 rounded-md text-sm font-medium transition-colors text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700 hover:text-gray-900 dark:hover:text-white`}
										>
											<Icon className="w-5 h-5" />
											<span>{item.name}</span>
										</a>
									);
								}

								return (
									<Link
										key={item.name}
										href={item.href}
										onClick={() => {
											// モバイルの場合のみサイドバーを閉じる
											if (isMobile()) {
												setIsSidebarOpen(false);
											}
										}}
										className={`flex items-center gap-3 px-3 py-2 rounded-md text-sm font-medium transition-colors ${
											isActive
												? "bg-gray-200 dark:bg-gray-700 text-gray-900 dark:text-white"
												: "text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700 hover:text-gray-900 dark:hover:text-white"
										}`}
									>
										<Icon className="w-5 h-5" />
										<span>{item.name}</span>
									</Link>
								);
							})}
						</div>
					</nav>

					{/* ユーザー情報 */}
					<div className="p-4 border-t border-gray-200 dark:border-gray-800">
						{!loading && (
							<div className="space-y-3">
								{user ? (
									<>
										<div className="flex items-center gap-2">
											<User className="w-4 h-4" />
											<span className="text-sm truncate">{user.email}</span>
										</div>
										<div className="flex items-center gap-2 text-xs text-gray-500 dark:text-gray-400">
											<span className="px-2 py-1 rounded-full bg-gray-200 dark:bg-gray-700">
												{role === "admin"
													? "Admin"
													: role === "writer"
														? "Writer"
														: "Viewer"}
											</span>
										</div>
										<button
											type="button"
											onClick={() => signOut()}
											className="flex items-center justify-center gap-2 w-full px-3 py-2 rounded-md text-sm font-medium bg-red-600 text-white hover:bg-red-700 transition-colors"
										>
											<LogOut className="w-4 h-4" />
											<span>Sign Out</span>
										</button>
									</>
								) : (
									<>
										<div className="flex items-center gap-2">
											<User className="w-4 h-4" />
											<span className="text-sm">ゲストユーザー</span>
										</div>
										<div className="flex items-center gap-2 text-xs text-gray-500 dark:text-gray-400">
											<span className="px-2 py-1 rounded-full bg-gray-200 dark:bg-gray-700">
												Viewer (読み取り専用)
											</span>
										</div>
										<button
											type="button"
											onClick={() => signInWithGoogle()}
											className="flex items-center justify-center gap-2 w-full px-3 py-2 rounded-md text-sm font-medium bg-blue-600 text-white hover:bg-blue-700 transition-colors"
										>
											<LogIn className="w-4 h-4" />
											<span>ログイン</span>
										</button>
									</>
								)}
							</div>
						)}
					</div>
				</div>
			</div>

			{/* オーバーレイ（モバイルのみ） */}
			{isSidebarOpen && (
				<button
					type="button"
					className="fixed inset-0 z-30 bg-black bg-opacity-50 md:hidden"
					onClick={() => setIsSidebarOpen(false)}
					aria-label="Close sidebar"
				/>
			)}

			{/* デスクトップ用の開くボタン（サイドバーが閉じている時） */}
			{!isSidebarOpen && (
				<button
					type="button"
					onClick={toggleSidebar}
					className="hidden md:flex fixed left-0 top-20 z-30 p-2 bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-r-md hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors shadow-md"
					title="Open sidebar"
				>
					<ChevronRight className="w-5 h-5" />
				</button>
			)}
		</>
	);
}

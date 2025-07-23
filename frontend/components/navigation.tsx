"use client";

import { LogIn, LogOut, Moon, Sun, User } from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";

interface NavItem {
	name: string;
	href: string;
	adminOnly?: boolean;
}

const navItems: NavItem[] = [
	{ name: "Dashboard", href: "/" },
	{ name: "Events", href: "/events" },
	{ name: "Commands", href: "/commands", adminOnly: true },
	{ name: "Queries", href: "/queries" },
	{ name: "Sagas", href: "/sagas" },
	{ name: "PubSub", href: "/pubsub" },
	{ name: "Metrics", href: "/metrics" },
	{ name: "Health", href: "/health" },
	{ name: "Topology", href: "/topology" },
	{ name: "GraphQL", href: "/graphql-playground", adminOnly: true },
];

type UserType = { email: string } | null;

export function Navigation() {
	const pathname = usePathname();
	const [currentTime, setCurrentTime] = useState<string>("");
	const [isDarkMode, setIsDarkMode] = useState<boolean>(true);

	// TODO: Implement Firebase Authentication
	const user: UserType = null;
	const isAdmin = false;

	useEffect(() => {
		const updateTime = () => {
			setCurrentTime(new Date().toLocaleTimeString());
		};

		updateTime();
		const interval = setInterval(updateTime, 1000);

		return () => clearInterval(interval);
	}, []);

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

	return (
		<nav className="bg-white dark:bg-gray-900 text-gray-900 dark:text-white border-b border-gray-200 dark:border-gray-800">
			<div className="container mx-auto px-4">
				<div className="flex items-center justify-between h-16">
					<div className="flex items-center space-x-8">
						<h1 className="text-xl font-bold">CQRS/ES Monitor</h1>
						<div className="flex space-x-4">
							{navItems
								.filter(
									(item) => !item.adminOnly || (item.adminOnly && isAdmin),
								)
								.map((item) => (
									<Link
										key={item.name}
										href={item.href}
										className={`px-3 py-2 rounded-md text-sm font-medium transition-colors ${
											pathname === item.href
												? "bg-gray-200 dark:bg-gray-700 text-gray-900 dark:text-white"
												: "text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700 hover:text-gray-900 dark:hover:text-white"
										}`}
									>
										{item.name}
									</Link>
								))}
						</div>
					</div>
					<div className="flex items-center space-x-4">
						<button
							type="button"
							onClick={toggleDarkMode}
							className="p-2 rounded-md hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors"
							aria-label="Toggle dark mode"
						>
							{isDarkMode ? (
								<Sun className="w-5 h-5" />
							) : (
								<Moon className="w-5 h-5" />
							)}
						</button>
						<span className="text-sm text-gray-600 dark:text-gray-400">
							{currentTime}
						</span>

						{user ? (
							<div className="flex items-center space-x-3">
								<div className="flex items-center space-x-2">
									<User className="w-4 h-4" />
									<span className="text-sm">
										{(user as UserType)?.email || ""}
									</span>
								</div>
								<button
									type="button"
									onClick={() => {
										// TODO: Implement Firebase logout
										console.log("Logout clicked");
									}}
									className="flex items-center space-x-1 px-3 py-2 rounded-md text-sm font-medium bg-red-600 text-white hover:bg-red-700 transition-colors"
								>
									<LogOut className="w-4 h-4" />
									<span>Logout</span>
								</button>
							</div>
						) : (
							<button
								type="button"
								onClick={() => {
									// TODO: Implement Firebase login
									console.log("Login clicked");
								}}
								className="flex items-center space-x-1 px-3 py-2 rounded-md text-sm font-medium bg-blue-600 text-white hover:bg-blue-700 transition-colors"
							>
								<LogIn className="w-4 h-4" />
								<span>Login</span>
							</button>
						)}
					</div>
				</div>
			</div>
		</nav>
	);
}

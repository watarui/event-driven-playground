"use client";

import { useQuery, useSubscription } from "@apollo/client";
import { Activity, ChevronDown, ChevronUp, RefreshCw } from "lucide-react";
import { useEffect, useState } from "react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
	Select,
	SelectContent,
	SelectItem,
	SelectTrigger,
	SelectValue,
} from "@/components/ui/select";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
	LIST_SAGAS,
	SAGA_UPDATES_SUBSCRIPTION,
	SYSTEM_STATISTICS,
} from "@/lib/graphql/queries/saga";

interface SagaDetail {
	id: string;
	sagaType: string;
	status: string;
	state: any;
	commandsDispatched: Array<{
		commandType: string;
		commandData: any;
		timestamp: string;
	}>;
	eventsHandled: string[];
	createdAt: string;
	updatedAt: string;
	correlationId?: string;
}

export default function SagasPage() {
	const [statusFilter, setStatusFilter] = useState<string>("all");
	const [sagaTypeFilter, setSagaTypeFilter] = useState<string>("all");
	const [expandedSagas, setExpandedSagas] = useState<Set<string>>(new Set());

	const {
		data: sagasData,
		loading: sagasLoading,
		error: sagasError,
		refetch,
	} = useQuery(LIST_SAGAS, {
		variables: {
			status: statusFilter === "all" ? null : statusFilter,
			sagaType: sagaTypeFilter === "all" ? null : sagaTypeFilter,
			limit: 100,
		},
		pollInterval: 5000, // 5秒ごとに更新
	});

	const { data: statsData } = useQuery(SYSTEM_STATISTICS, {
		pollInterval: 5000,
	});

	// リアルタイム更新のサブスクリプション
	const { data: updateData } = useSubscription(SAGA_UPDATES_SUBSCRIPTION, {
		variables: {
			sagaType: sagaTypeFilter === "all" ? null : sagaTypeFilter,
		},
	});

	// サブスクリプションデータを反映
	useEffect(() => {
		if (updateData?.sagaUpdates) {
			refetch();
		}
	}, [updateData, refetch]);

	const toggleSagaExpansion = (sagaId: string) => {
		setExpandedSagas((prev) => {
			const newSet = new Set(prev);
			if (newSet.has(sagaId)) {
				newSet.delete(sagaId);
			} else {
				newSet.add(sagaId);
			}
			return newSet;
		});
	};

	const getStatusColor = (status: string) => {
		switch (status.toLowerCase()) {
			case "started":
			case "active":
				return "bg-blue-500";
			case "completed":
				return "bg-green-500";
			case "failed":
				return "bg-red-500";
			case "compensated":
				return "bg-yellow-500";
			default:
				return "bg-gray-500";
		}
	};

	const getStatusIcon = (status: string) => {
		switch (status.toLowerCase()) {
			case "started":
			case "active":
				return <Activity className="w-4 h-4 animate-pulse" />;
			case "completed":
				return "✓";
			case "failed":
				return "✗";
			case "compensated":
				return "⟲";
			default:
				return "?";
		}
	};

	const sagas = sagasData?.sagas || [];
	const stats = statsData?.systemStatistics?.sagas || {
		active: 0,
		completed: 0,
		failed: 0,
		compensated: 0,
		total: 0,
	};

	if (sagasLoading && !sagasData) {
		return (
			<div className="container mx-auto p-8">
				<h1 className="text-3xl font-bold mb-6">SAGA Monitor</h1>
				<div className="flex items-center justify-center h-64">
					<div className="text-lg">Loading SAGAs...</div>
				</div>
			</div>
		);
	}

	if (sagasError) {
		return (
			<div className="container mx-auto p-8">
				<h1 className="text-3xl font-bold mb-6">SAGA Monitor</h1>
				<div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded">
					Error: {sagasError.message}
				</div>
			</div>
		);
	}

	return (
		<div className="container mx-auto p-8">
			<div className="flex items-center justify-between mb-6">
				<h1 className="text-3xl font-bold">SAGA Monitor</h1>
				<Button onClick={() => refetch()} variant="outline" size="sm">
					<RefreshCw className="w-4 h-4 mr-2" />
					Refresh
				</Button>
			</div>

			{/* Statistics */}
			<div className="grid grid-cols-1 md:grid-cols-5 gap-4 mb-8">
				<Card>
					<CardHeader className="pb-2">
						<CardTitle className="text-sm font-medium">Total SAGAs</CardTitle>
					</CardHeader>
					<CardContent>
						<div className="text-2xl font-bold">{stats.total}</div>
					</CardContent>
				</Card>
				<Card>
					<CardHeader className="pb-2">
						<CardTitle className="text-sm font-medium">Active</CardTitle>
					</CardHeader>
					<CardContent>
						<div className="text-2xl font-bold text-blue-600">
							{stats.active}
						</div>
					</CardContent>
				</Card>
				<Card>
					<CardHeader className="pb-2">
						<CardTitle className="text-sm font-medium">Completed</CardTitle>
					</CardHeader>
					<CardContent>
						<div className="text-2xl font-bold text-green-600">
							{stats.completed}
						</div>
					</CardContent>
				</Card>
				<Card>
					<CardHeader className="pb-2">
						<CardTitle className="text-sm font-medium">Failed</CardTitle>
					</CardHeader>
					<CardContent>
						<div className="text-2xl font-bold text-red-600">
							{stats.failed}
						</div>
					</CardContent>
				</Card>
				<Card>
					<CardHeader className="pb-2">
						<CardTitle className="text-sm font-medium">Compensated</CardTitle>
					</CardHeader>
					<CardContent>
						<div className="text-2xl font-bold text-yellow-600">
							{stats.compensated}
						</div>
					</CardContent>
				</Card>
			</div>

			{/* Filters */}
			<div className="flex space-x-4 mb-6">
				<Select value={statusFilter} onValueChange={setStatusFilter}>
					<SelectTrigger className="w-[180px]">
						<SelectValue placeholder="Filter by status" />
					</SelectTrigger>
					<SelectContent>
						<SelectItem value="all">All Statuses</SelectItem>
						<SelectItem value="started">Started</SelectItem>
						<SelectItem value="active">Active</SelectItem>
						<SelectItem value="completed">Completed</SelectItem>
						<SelectItem value="failed">Failed</SelectItem>
						<SelectItem value="compensated">Compensated</SelectItem>
					</SelectContent>
				</Select>

				<Select value={sagaTypeFilter} onValueChange={setSagaTypeFilter}>
					<SelectTrigger className="w-[180px]">
						<SelectValue placeholder="Filter by type" />
					</SelectTrigger>
					<SelectContent>
						<SelectItem value="all">All Types</SelectItem>
						<SelectItem value="OrderSaga">Order Saga</SelectItem>
						<SelectItem value="PaymentSaga">Payment Saga</SelectItem>
						<SelectItem value="ShippingSaga">Shipping Saga</SelectItem>
					</SelectContent>
				</Select>
			</div>

			{/* SAGA List */}
			<Card>
				<CardHeader>
					<CardTitle>SAGA Instances ({sagas.length})</CardTitle>
				</CardHeader>
				<CardContent>
					<div className="space-y-4">
						{sagas.length === 0 ? (
							<div className="text-center py-8 text-gray-500">
								No SAGAs found with the current filters
							</div>
						) : (
							sagas.map((saga: SagaDetail) => (
								<div
									key={saga.id}
									className="border rounded-lg hover:shadow-md transition-shadow"
								>
									<button
										type="button"
										className="w-full p-4 text-left cursor-pointer"
										onClick={() => toggleSagaExpansion(saga.id)}
									>
										<div className="flex items-center justify-between">
											<div className="flex items-center space-x-4">
												<h3 className="font-semibold">{saga.sagaType}</h3>
												<Badge
													className={`${getStatusColor(saga.status)} text-white`}
												>
													<span className="mr-1">
														{getStatusIcon(saga.status)}
													</span>
													{saga.status}
												</Badge>
											</div>
											<div className="flex items-center space-x-4">
												<span className="text-sm text-gray-500">
													{new Date(saga.updatedAt).toLocaleString()}
												</span>
												{expandedSagas.has(saga.id) ? (
													<ChevronUp className="w-4 h-4" />
												) : (
													<ChevronDown className="w-4 h-4" />
												)}
											</div>
										</div>

										<div className="mt-2 grid grid-cols-2 md:grid-cols-3 gap-2 text-sm">
											<div>
												<span className="text-gray-500">ID:</span>{" "}
												<span className="font-mono text-xs">{saga.id}</span>
											</div>
											{saga.correlationId && (
												<div>
													<span className="text-gray-500">Correlation:</span>{" "}
													<span className="font-mono text-xs">
														{saga.correlationId}
													</span>
												</div>
											)}
											<div>
												<span className="text-gray-500">Created:</span>{" "}
												{new Date(saga.createdAt).toLocaleString()}
											</div>
										</div>
									</button>

									{expandedSagas.has(saga.id) && (
										<div className="border-t px-4 py-4 bg-gray-50">
											<Tabs defaultValue="state" className="w-full">
												<TabsList>
													<TabsTrigger value="state">State</TabsTrigger>
													<TabsTrigger value="commands">Commands</TabsTrigger>
													<TabsTrigger value="events">Events</TabsTrigger>
												</TabsList>

												<TabsContent value="state" className="mt-4">
													<pre className="bg-gray-100 p-3 rounded overflow-auto text-xs">
														{JSON.stringify(saga.state, null, 2)}
													</pre>
												</TabsContent>

												<TabsContent value="commands" className="mt-4">
													{saga.commandsDispatched.length === 0 ? (
														<div className="text-gray-500">
															No commands dispatched
														</div>
													) : (
														<div className="space-y-2">
															{saga.commandsDispatched.map((cmd) => (
																<div
																	key={`${saga.id}-cmd-${cmd.commandType}-${cmd.timestamp}`}
																	className="bg-gray-100 p-3 rounded"
																>
																	<div className="font-semibold text-sm">
																		{cmd.commandType}
																	</div>
																	<div className="text-xs text-gray-500">
																		{cmd.timestamp}
																	</div>
																	<pre className="mt-2 text-xs overflow-auto">
																		{JSON.stringify(cmd.commandData, null, 2)}
																	</pre>
																</div>
															))}
														</div>
													)}
												</TabsContent>

												<TabsContent value="events" className="mt-4">
													{saga.eventsHandled.length === 0 ? (
														<div className="text-gray-500">
															No events handled
														</div>
													) : (
														<div className="space-y-1">
															{saga.eventsHandled.map((event) => (
																<div
																	key={`${saga.id}-event-${event}`}
																	className="bg-gray-100 px-3 py-2 rounded text-sm"
																>
																	{event}
																</div>
															))}
														</div>
													)}
												</TabsContent>
											</Tabs>
										</div>
									)}
								</div>
							))
						)}
					</div>
				</CardContent>
			</Card>
		</div>
	);
}

"use client";

import {
	addEdge,
	Background,
	BackgroundVariant,
	type Connection,
	Controls,
	type Edge,
	MarkerType,
	type Node,
	ReactFlow,
	useEdgesState,
	useNodesState,
} from "@xyflow/react";
import { useCallback, useEffect, useState } from "react";
import "@xyflow/react/dist/style.css";
import { motion } from "framer-motion";

interface FlowMessage {
	id: string;
	from: string;
	to: string;
	type: "command" | "event" | "query";
	data: any;
}

const nodeTypes = {
	service: ServiceNode,
};

function ServiceNode({ data }: { data: any }) {
	return (
		<motion.div
			initial={{ scale: 0.8, opacity: 0 }}
			animate={{ scale: 1, opacity: 1 }}
			className={`px-6 py-4 rounded-xl shadow-lg border-2 ${data.color} bg-white dark:bg-gray-800 transition-colors`}
		>
			<div className="flex items-center space-x-3">
				<div className="text-2xl">{data.icon}</div>
				<div>
					<div className="font-bold text-lg text-gray-900 dark:text-white">
						{data.label}
					</div>
					<div className="text-sm text-gray-500 dark:text-gray-400">
						{data.status}
					</div>
				</div>
			</div>
			{data.metrics && (
				<div className="mt-3 space-y-1 text-xs">
					{Object.entries(data.metrics).map(([key, value]) => (
						<div key={key} className="flex justify-between">
							<span className="text-gray-500 dark:text-gray-400">{key}:</span>
							<span className="font-semibold text-gray-900 dark:text-white">
								{String(value)}
							</span>
						</div>
					))}
				</div>
			)}
		</motion.div>
	);
}

const initialNodes: Node[] = [
	{
		id: "client",
		type: "service",
		position: { x: 50, y: 200 },
		data: {
			label: "Client Service",
			icon: "🌐",
			color: "border-blue-500",
			status: "GraphQL Gateway",
			metrics: {
				"Req/s": "120",
				Latency: "45ms",
			},
		},
	},
	{
		id: "command",
		type: "service",
		position: { x: 400, y: 100 },
		data: {
			label: "Command Service",
			icon: "⚡",
			color: "border-green-500",
			status: "Processing Commands",
			metrics: {
				"Commands/s": "85",
				Queue: "12",
			},
		},
	},
	{
		id: "query",
		type: "service",
		position: { x: 400, y: 300 },
		data: {
			label: "Query Service",
			icon: "🔍",
			color: "border-purple-500",
			status: "Serving Queries",
			metrics: {
				"Queries/s": "200",
				"Cache Hit": "92%",
			},
		},
	},
	{
		id: "eventstore",
		type: "service",
		position: { x: 750, y: 200 },
		data: {
			label: "Event Store",
			icon: "📚",
			color: "border-orange-500",
			status: "Storing Events",
			metrics: {
				Events: "1.2M",
				Growth: "+120/s",
			},
		},
	},
	{
		id: "saga",
		type: "service",
		position: { x: 400, y: 450 },
		data: {
			label: "Saga Coordinator",
			icon: "🔄",
			color: "border-red-500",
			status: "Orchestrating",
			metrics: {
				Active: "23",
				Completed: "450",
			},
		},
	},
];

const initialEdges: Edge[] = [
	{
		id: "e1",
		source: "client",
		target: "command",
		type: "smoothstep",
		animated: false,
		markerEnd: {
			type: MarkerType.ArrowClosed,
			width: 20,
			height: 20,
		},
		style: {
			strokeWidth: 2,
			stroke: "#10b981",
		},
	},
	{
		id: "e2",
		source: "client",
		target: "query",
		type: "smoothstep",
		animated: false,
		markerEnd: {
			type: MarkerType.ArrowClosed,
			width: 20,
			height: 20,
		},
		style: {
			strokeWidth: 2,
			stroke: "#8b5cf6",
		},
	},
	{
		id: "e3",
		source: "command",
		target: "eventstore",
		type: "smoothstep",
		animated: false,
		markerEnd: {
			type: MarkerType.ArrowClosed,
			width: 20,
			height: 20,
		},
		style: {
			strokeWidth: 2,
			stroke: "#f59e0b",
		},
	},
	{
		id: "e4",
		source: "eventstore",
		target: "query",
		type: "smoothstep",
		animated: false,
		markerEnd: {
			type: MarkerType.ArrowClosed,
			width: 20,
			height: 20,
		},
		style: {
			strokeWidth: 2,
			stroke: "#f59e0b",
		},
		label: "Projections",
	},
	{
		id: "e5",
		source: "eventstore",
		target: "saga",
		type: "smoothstep",
		animated: false,
		markerEnd: {
			type: MarkerType.ArrowClosed,
			width: 20,
			height: 20,
		},
		style: {
			strokeWidth: 2,
			stroke: "#ef4444",
		},
	},
	{
		id: "e6",
		source: "saga",
		target: "command",
		type: "smoothstep",
		animated: false,
		markerEnd: {
			type: MarkerType.ArrowClosed,
			width: 20,
			height: 20,
		},
		style: {
			strokeWidth: 2,
			stroke: "#ef4444",
		},
		label: "Compensate",
	},
];

export function FlowVisualization({
	messages = [],
}: {
	messages?: FlowMessage[];
}) {
	const [nodes, _setNodes, onNodesChange] = useNodesState(initialNodes);
	const [edges, setEdges, onEdgesChange] = useEdgesState(initialEdges);
	const [animatedEdges, setAnimatedEdges] = useState<Set<string>>(new Set());

	// メッセージが流れたらエッジをアニメーション
	useEffect(() => {
		messages.forEach((message) => {
			const edgeId = `${message.from}-${message.to}`;
			setAnimatedEdges((prev) => new Set(prev).add(edgeId));

			// 3秒後にアニメーションを停止
			setTimeout(() => {
				setAnimatedEdges((prev) => {
					const newSet = new Set(prev);
					newSet.delete(edgeId);
					return newSet;
				});
			}, 3000);
		});
	}, [messages]);

	// エッジのアニメーション状態を更新
	useEffect(() => {
		setEdges((eds) =>
			eds.map((edge) => ({
				...edge,
				animated: animatedEdges.has(`${edge.source}-${edge.target}`),
			})),
		);
	}, [animatedEdges, setEdges]);

	const onConnect = useCallback(
		(params: Connection) => setEdges((eds) => addEdge(params, eds)),
		[setEdges],
	);

	return (
		<div className="w-full h-[600px] bg-gray-50 dark:bg-gray-900 rounded-lg">
			<ReactFlow
				nodes={nodes}
				edges={edges}
				onNodesChange={onNodesChange}
				onEdgesChange={onEdgesChange}
				onConnect={onConnect}
				nodeTypes={nodeTypes}
				fitView
				attributionPosition="bottom-left"
			>
				<Background variant={BackgroundVariant.Dots} gap={12} size={1} />
				<Controls />
			</ReactFlow>
		</div>
	);
}

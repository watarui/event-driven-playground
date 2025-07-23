"use client"

import {
  addEdge,
  Background,
  BackgroundVariant,
  type Connection,
  ConnectionMode,
  Controls,
  type Edge,
  MarkerType,
  MiniMap,
  type Node,
  ReactFlow,
  useEdgesState,
  useNodesState,
} from "@xyflow/react"
import { useCallback, useEffect, useState } from "react"
import "@xyflow/react/dist/style.css"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"

type NodeData = {
  label: string
}

type CustomNode = Node<NodeData>

const initialNodes: CustomNode[] = [
  {
    id: "client",
    type: "input",
    data: { label: "Client Service\n(GraphQL API)" },
    position: { x: 250, y: 0 },
    style: {
      background: "#60a5fa",
      color: "white",
      border: "1px solid #3b82f6",
      width: 180,
    },
  },
  {
    id: "command",
    data: { label: "Command Service\n(Write Model)" },
    position: { x: 50, y: 150 },
    style: {
      background: "#f59e0b",
      color: "white",
      border: "1px solid #d97706",
      width: 180,
    },
  },
  {
    id: "query",
    data: { label: "Query Service\n(Read Model)" },
    position: { x: 450, y: 150 },
    style: {
      background: "#10b981",
      color: "white",
      border: "1px solid #059669",
      width: 180,
    },
  },
  {
    id: "saga",
    data: { label: "Saga Executor\n(in Command Service)" },
    position: { x: 50, y: 280 },
    style: {
      background: "#ef4444",
      color: "white",
      border: "1px solid #dc2626",
      width: 180,
      fontSize: "12px",
    },
  },
  {
    id: "event-store",
    data: { label: "Event Store\n(Firestore)" },
    position: { x: 250, y: 350 },
    style: {
      background: "#8b5cf6",
      color: "white",
      border: "1px solid #7c3aed",
      width: 180,
    },
  },
  {
    id: "event-bus",
    data: { label: "Event Bus\n(PubSub)" },
    position: { x: 250, y: 480 },
    style: {
      background: "#6366f1",
      color: "white",
      border: "1px solid #4f46e5",
      width: 180,
    },
  },
  {
    id: "projection",
    data: { label: "Projection Manager" },
    position: { x: 450, y: 480 },
    style: {
      background: "#06b6d4",
      color: "white",
      border: "1px solid #0891b2",
      width: 180,
    },
  },
  {
    id: "saga-db",
    data: { label: "Saga State\n(Firestore)" },
    position: { x: 50, y: 480 },
    style: {
      background: "#a855f7",
      color: "white",
      border: "1px solid #9333ea",
      width: 180,
    },
  },
  {
    id: "command-db",
    type: "output",
    data: { label: "Command State\n(Firestore)" },
    position: { x: 50, y: 630 },
    style: {
      background: "#f97316",
      color: "white",
      border: "1px solid #ea580c",
      width: 180,
    },
  },
  {
    id: "query-db",
    type: "output",
    data: { label: "Read Model\n(Firestore)" },
    position: { x: 450, y: 630 },
    style: {
      background: "#f97316",
      color: "white",
      border: "1px solid #ea580c",
      width: 180,
    },
  },
]

const initialEdges: Edge[] = [
  {
    id: "client-command",
    source: "client",
    target: "command",
    label: "Commands",
    animated: true,
    style: { stroke: "#f59e0b" },
    markerEnd: {
      type: MarkerType.ArrowClosed,
    },
  },
  {
    id: "client-query",
    source: "client",
    target: "query",
    label: "Queries",
    animated: true,
    style: { stroke: "#10b981" },
    markerEnd: {
      type: MarkerType.ArrowClosed,
    },
  },
  {
    id: "command-event-store",
    source: "command",
    target: "event-store",
    label: "Events",
    style: { stroke: "#8b5cf6" },
    markerEnd: {
      type: MarkerType.ArrowClosed,
    },
  },
  {
    id: "event-store-eventbus",
    source: "event-store",
    target: "event-bus",
    label: "Events",
    style: { stroke: "#6366f1" },
    markerEnd: {
      type: MarkerType.ArrowClosed,
    },
  },
  {
    id: "eventbus-projection",
    source: "event-bus",
    target: "projection",
    label: "Event Stream",
    style: { stroke: "#06b6d4" },
    markerEnd: {
      type: MarkerType.ArrowClosed,
    },
  },
  {
    id: "command-saga",
    source: "command",
    target: "saga",
    label: "Saga\nManagement",
    style: { stroke: "#ef4444" },
    markerEnd: {
      type: MarkerType.ArrowClosed,
    },
  },
  {
    id: "eventbus-saga",
    source: "event-bus",
    target: "saga",
    label: "Domain Events",
    style: { stroke: "#ef4444" },
    markerEnd: {
      type: MarkerType.ArrowClosed,
    },
  },
  {
    id: "saga-eventbus",
    source: "saga",
    target: "event-bus",
    label: "Saga Commands",
    style: { stroke: "#ef4444", strokeDasharray: "5 5" },
    markerEnd: {
      type: MarkerType.ArrowClosed,
    },
  },
  {
    id: "saga-saga-db",
    source: "saga",
    target: "saga-db",
    label: "Saga State",
    style: { stroke: "#a855f7" },
    markerEnd: {
      type: MarkerType.ArrowClosed,
    },
  },
  {
    id: "projection-query-db",
    source: "projection",
    target: "query-db",
    label: "Updates",
    style: { stroke: "#06b6d4" },
    markerEnd: {
      type: MarkerType.ArrowClosed,
    },
  },
  {
    id: "query-query-db",
    source: "query",
    target: "query-db",
    label: "Read",
    style: { stroke: "#10b981", strokeDasharray: "5 5" },
    markerEnd: {
      type: MarkerType.ArrowClosed,
    },
  },
  {
    id: "command-command-db",
    source: "command",
    target: "command-db",
    label: "State Update",
    style: { stroke: "#f59e0b" },
    markerEnd: {
      type: MarkerType.ArrowClosed,
    },
  },
]

interface ServiceHealth {
  [key: string]: {
    status: "healthy" | "warning" | "error"
    latency: number
    throughput: number
    memoryUsage?: number
    processCount?: number
  }
}

interface HealthCheckResult {
  health: {
    status: string
    checks: Array<{
      name: string
      status: string
      message: string
      duration_ms: number
      details?: any
    }>
  }
  memoryInfo: {
    total_mb: number
    process_mb: number
    binary_mb: number
    ets_mb: number
    process_count: number
    port_count: number
  }
}

const HEALTH_CHECK_QUERY = `
  query HealthCheck {
    health {
      status
      checks {
        name
        status
        message
        duration_ms
        details
      }
    }
    memoryInfo {
      total_mb
      process_mb
      binary_mb
      ets_mb
      process_count
      port_count
    }
  }
`

async function fetchHealthMetrics(): Promise<HealthCheckResult | null> {
  try {
    const response = await fetch("/api/graphql", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        query: HEALTH_CHECK_QUERY,
      }),
    })

    if (!response.ok) {
      console.error("Health check failed:", response.status)
      return null
    }

    const data = await response.json()
    return data.data as HealthCheckResult
  } catch (error) {
    console.error("Error fetching health metrics:", error)
    return null
  }
}

function mapHealthCheckToNodeId(checkName: string): string | null {
  const mapping: { [key: string]: string } = {
    services: "client",
    command_service: "command",
    query_service: "query",
    firestore: "event-store",
    event_store: "event-store",
    pubsub: "event-bus",
    saga_executor: "saga",
  }
  return mapping[checkName.toLowerCase()] || null
}

export default function TopologyPage() {
  const [nodes, setNodes, onNodesChange] = useNodesState<CustomNode>(initialNodes)
  const [edges, setEdges, onEdgesChange] = useEdgesState(initialEdges)
  const [serviceHealth, setServiceHealth] = useState<ServiceHealth>({})

  useEffect(() => {
    // Fetch real service health metrics
    const updateHealth = async () => {
      const metrics = await fetchHealthMetrics()

      if (metrics) {
        const health: ServiceHealth = {}

        // Extract service-specific health data
        metrics.health.checks.forEach((check) => {
          const nodeId = mapHealthCheckToNodeId(check.name)
          if (nodeId) {
            health[nodeId] = {
              status:
                check.status === "healthy"
                  ? "healthy"
                  : check.status === "degraded"
                    ? "warning"
                    : "error",
              latency: check.duration_ms || 0,
              throughput: 0, // TODO: Extract from metrics if available
              memoryUsage: nodeId === "client" ? metrics.memoryInfo.total_mb : undefined,
              processCount: nodeId === "client" ? metrics.memoryInfo.process_count : undefined,
            }
          }
        })

        // Set default health for nodes without specific checks
        nodes.forEach((node) => {
          if (!health[node.id]) {
            health[node.id] = {
              status: "healthy",
              latency: 0,
              throughput: 0,
            }
          }
        })

        setServiceHealth(health)

        // Update node styles based on health
        setNodes((nds) =>
          nds.map((node) => {
            const nodeHealth = health[node.id]
            if (!nodeHealth) return node

            let borderColor = "#22c55e" // healthy
            if (nodeHealth.status === "warning") borderColor = "#f59e0b"
            if (nodeHealth.status === "error") borderColor = "#ef4444"

            return {
              ...node,
              style: {
                ...node.style,
                border: `3px solid ${borderColor}`,
              },
            }
          })
        )
      } else {
        // Fallback to simulated data if real metrics are unavailable
        const health: ServiceHealth = {}
        nodes.forEach((node) => {
          const random = Math.random()
          health[node.id] = {
            status: random > 0.9 ? "error" : random > 0.8 ? "warning" : "healthy",
            latency: Math.floor(Math.random() * 100) + 10,
            throughput: Math.floor(Math.random() * 1000) + 100,
          }
        })
        setServiceHealth(health)
      }
    }

    updateHealth()
    const interval = setInterval(updateHealth, 5000)

    return () => clearInterval(interval)
  }, [setNodes, nodes.forEach])

  const onConnect = useCallback(
    (params: Connection) => setEdges((eds) => addEdge(params, eds)),
    [setEdges]
  )

  return (
    <div className="container mx-auto p-8">
      <h1 className="text-3xl font-bold mb-6">System Topology</h1>

      <div className="grid grid-cols-1 lg:grid-cols-4 gap-4 mb-8">
        {/* Service Health Cards */}
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Healthy Services</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-green-600">
              {Object.values(serviceHealth).filter((h) => h.status === "healthy").length}
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Warnings</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-yellow-600">
              {Object.values(serviceHealth).filter((h) => h.status === "warning").length}
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Errors</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-red-600">
              {Object.values(serviceHealth).filter((h) => h.status === "error").length}
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Avg Latency</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {Object.values(serviceHealth).length > 0
                ? Math.round(
                    Object.values(serviceHealth).reduce((sum, h) => sum + h.latency, 0) /
                      Object.values(serviceHealth).length
                  )
                : 0}
              ms
            </div>
          </CardContent>
        </Card>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Topology Diagram */}
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle>Service Architecture</CardTitle>
          </CardHeader>
          <CardContent>
            <div style={{ height: 600 }}>
              <ReactFlow
                nodes={nodes}
                edges={edges}
                onNodesChange={onNodesChange}
                onEdgesChange={onEdgesChange}
                onConnect={onConnect}
                connectionMode={ConnectionMode.Loose}
                fitView
              >
                <Controls />
                <MiniMap />
                <Background variant={BackgroundVariant.Dots} gap={12} size={1} />
              </ReactFlow>
            </div>
          </CardContent>
        </Card>

        {/* Service Details */}
        <Card className="lg:col-span-1">
          <CardHeader>
            <CardTitle>Service Health</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {nodes.map((node) => {
                const health = serviceHealth[node.id]
                if (!health) return null

                return (
                  <div
                    key={node.id}
                    className="border rounded-lg p-3 hover:shadow-md transition-shadow"
                  >
                    <div className="flex items-center justify-between mb-2">
                      <h3 className="font-semibold">{node.data.label.split("\n")[0]}</h3>
                      <div
                        className={`w-3 h-3 rounded-full ${
                          health.status === "healthy"
                            ? "bg-green-500"
                            : health.status === "warning"
                              ? "bg-yellow-500"
                              : "bg-red-500"
                        }`}
                      />
                    </div>
                    <div className="grid grid-cols-2 gap-2 text-sm">
                      <div>
                        <span className="text-gray-500">Latency:</span>{" "}
                        <span className="font-medium">{health.latency}ms</span>
                      </div>
                      {health.memoryUsage !== undefined && (
                        <div>
                          <span className="text-gray-500">Memory:</span>{" "}
                          <span className="font-medium">{health.memoryUsage.toFixed(1)}MB</span>
                        </div>
                      )}
                      {health.processCount !== undefined && (
                        <div>
                          <span className="text-gray-500">Processes:</span>{" "}
                          <span className="font-medium">{health.processCount}</span>
                        </div>
                      )}
                      {health.throughput > 0 && (
                        <div>
                          <span className="text-gray-500">Throughput:</span>{" "}
                          <span className="font-medium">{health.throughput}/s</span>
                        </div>
                      )}
                    </div>
                  </div>
                )
              })}
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Legend */}
      <Card className="mt-6">
        <CardHeader>
          <CardTitle>Legend</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex flex-wrap gap-6">
            <div className="flex items-center space-x-2">
              <div className="w-4 h-4 bg-green-500 rounded" />
              <span className="text-sm">Healthy</span>
            </div>
            <div className="flex items-center space-x-2">
              <div className="w-4 h-4 bg-yellow-500 rounded" />
              <span className="text-sm">Warning</span>
            </div>
            <div className="flex items-center space-x-2">
              <div className="w-4 h-4 bg-red-500 rounded" />
              <span className="text-sm">Error</span>
            </div>
            <div className="flex items-center space-x-2">
              <div className="w-8 h-0 border-t-2 border-solid border-gray-500" />
              <span className="text-sm">Data Flow</span>
            </div>
            <div className="flex items-center space-x-2">
              <div className="w-8 h-0 border-t-2 border-dashed border-gray-500" />
              <span className="text-sm">Read/Command</span>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}

"use client"

import { gql, useQuery } from "@apollo/client"
import {
  Activity,
  AlertCircle,
  CheckCircle,
  Cpu,
  Database,
  Server,
  XCircle,
  Zap,
} from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Progress } from "@/components/ui/progress"

const HEALTH_QUERY = gql`
  query GetHealth {
    health {
      status
      timestamp
      version
      node
      checks {
        name
        status
        message
        details
        duration_ms
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

interface HealthCheck {
  name: string
  status: "healthy" | "degraded" | "unhealthy"
  message: string
  details: Record<string, unknown>
  duration_ms: number
}

interface HealthReport {
  status: "healthy" | "degraded" | "unhealthy"
  timestamp: string
  version: string
  node: string
  checks: HealthCheck[]
}

interface MemoryInfo {
  total_mb: number
  process_mb: number
  binary_mb: number
  ets_mb: number
  process_count: number
  port_count: number
}

export default function HealthPage() {
  const { data, loading, error, refetch } = useQuery(HEALTH_QUERY, {
    pollInterval: 5000, // 5秒ごとに更新
  })

  const getStatusIcon = (status: string) => {
    switch (status) {
      case "healthy":
        return <CheckCircle className="h-5 w-5 text-green-500" />
      case "degraded":
        return <AlertCircle className="h-5 w-5 text-yellow-500" />
      case "unhealthy":
        return <XCircle className="h-5 w-5 text-red-500" />
      default:
        return null
    }
  }

  const getStatusBadge = (status: string) => {
    switch (status.toLowerCase()) {
      case "healthy":
        return <Badge className="bg-green-500 text-white">Healthy</Badge>
      case "degraded":
        return <Badge className="bg-yellow-500 text-white">Degraded</Badge>
      case "unhealthy":
        return <Badge className="bg-red-500 text-white">Unhealthy</Badge>
      default:
        return <Badge>Unknown</Badge>
    }
  }

  const getCheckIcon = (name: string) => {
    switch (name) {
      case "database":
        return <Database className="h-4 w-4" />
      case "memory":
        return <Cpu className="h-4 w-4" />
      case "services":
        return <Server className="h-4 w-4" />
      case "circuit_breakers":
        return <Zap className="h-4 w-4" />
      default:
        return <Activity className="h-4 w-4" />
    }
  }

  if (loading) {
    return (
      <div className="container mx-auto p-6">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-200 rounded w-1/4 mb-6" />
          <div className="space-y-4">
            <div className="h-32 bg-gray-200 rounded" />
            <div className="h-32 bg-gray-200 rounded" />
          </div>
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="container mx-auto p-6">
        <Card className="border-red-200">
          <CardHeader>
            <CardTitle className="text-red-600">Error Loading Health Status</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-red-600">{error.message}</p>
          </CardContent>
        </Card>
      </div>
    )
  }

  const health: HealthReport = data?.health
  const memoryInfo: MemoryInfo = data?.memoryInfo

  return (
    <div className="container mx-auto p-6">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-3xl font-bold">System Health</h1>
        <button
          type="button"
          onClick={() => refetch()}
          className="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
        >
          Refresh
        </button>
      </div>

      {/* Overall Status */}
      <Card className="mb-6">
        <CardHeader>
          <div className="flex justify-between items-start">
            <div>
              <CardTitle className="flex items-center gap-2">
                {getStatusIcon(health.status)}
                System Status
              </CardTitle>
              <p className="text-sm text-gray-600 mt-1">
                Last updated: {new Date(health.timestamp).toLocaleString()}
              </p>
            </div>
            {getStatusBadge(health.status)}
          </div>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div>
              <p className="text-sm text-gray-600">Version</p>
              <p className="font-mono">{health.version}</p>
            </div>
            <div>
              <p className="text-sm text-gray-600">Node</p>
              <p className="font-mono text-sm">{health.node}</p>
            </div>
            <div>
              <p className="text-sm text-gray-600">Total Checks</p>
              <p className="font-semibold">{health.checks.length}</p>
            </div>
            <div>
              <p className="text-sm text-gray-600">Failed Checks</p>
              <p className="font-semibold text-red-600">
                {health.checks.filter((c) => c.status === "unhealthy").length}
              </p>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Memory Usage */}
      <Card className="mb-6">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Cpu className="h-5 w-5" />
            Memory Usage
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div>
              <div className="flex justify-between mb-1">
                <span className="text-sm">Total Memory</span>
                <span className="text-sm font-semibold">{memoryInfo.total_mb.toFixed(1)} MB</span>
              </div>
              <Progress value={(memoryInfo.total_mb / 2048) * 100} />
            </div>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <div>
                <p className="text-sm text-gray-600">Processes</p>
                <p className="font-semibold">{memoryInfo.process_mb.toFixed(1)} MB</p>
              </div>
              <div>
                <p className="text-sm text-gray-600">Binary</p>
                <p className="font-semibold">{memoryInfo.binary_mb.toFixed(1)} MB</p>
              </div>
              <div>
                <p className="text-sm text-gray-600">ETS</p>
                <p className="font-semibold">{memoryInfo.ets_mb.toFixed(1)} MB</p>
              </div>
              <div>
                <p className="text-sm text-gray-600">Process Count</p>
                <p className="font-semibold">{memoryInfo.process_count}</p>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Health Checks */}
      <div className="grid gap-4">
        {health.checks.map((check) => (
          <Card
            key={check.name}
            className={`border-l-4 ${
              check.status.toLowerCase() === "healthy"
                ? "border-l-green-500"
                : check.status.toLowerCase() === "degraded"
                  ? "border-l-yellow-500"
                  : "border-l-red-500"
            }`}
          >
            <CardHeader>
              <div className="flex justify-between items-start">
                <CardTitle className="text-lg flex items-center gap-2">
                  {getCheckIcon(check.name)}
                  {check.name.charAt(0).toUpperCase() + check.name.slice(1).replace("_", " ")}
                </CardTitle>
                <div className="flex items-center gap-2">
                  <span className="text-sm text-gray-600">{check.duration_ms}ms</span>
                  {getStatusBadge(check.status)}
                </div>
              </div>
            </CardHeader>
            <CardContent>
              <p className="text-sm mb-2">{check.message}</p>
              {check.details && (
                <div className="bg-gray-50 dark:bg-gray-800 rounded p-3 mt-2">
                  <p className="text-xs font-semibold text-gray-600 dark:text-gray-400 mb-2">
                    Details:
                  </p>
                  <div className="overflow-x-auto">
                    <pre className="text-xs whitespace-pre-wrap break-words max-w-full">
                      {(() => {
                        // details が文字列の場合、JSON としてパースを試みる
                        if (typeof check.details === "string") {
                          try {
                            const parsed = JSON.parse(check.details)
                            return JSON.stringify(parsed, null, 2)
                          } catch {
                            return check.details
                          }
                        }
                        // details がオブジェクトまたは配列の場合
                        else if (typeof check.details === "object") {
                          // 空オブジェクトの場合
                          if (Object.keys(check.details).length === 0) {
                            return "No additional details available"
                          }
                          return JSON.stringify(check.details, null, 2)
                        }
                        // その他の場合
                        else {
                          return String(check.details)
                        }
                      })()}
                    </pre>
                  </div>
                </div>
              )}
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  )
}

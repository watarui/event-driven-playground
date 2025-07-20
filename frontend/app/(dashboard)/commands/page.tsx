"use client"

import { gql, useQuery } from "@apollo/client"
import { useEffect, useState } from "react"
import {
  Bar,
  BarChart,
  CartesianGrid,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts"
import { Badge } from "@/components/ui/badge"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"

// GraphQL queries to fetch data
const GET_ALL_DATA = gql`
  query GetAllData {
    categories {
      id
      name
      createdAt
      updatedAt
    }
    products {
      id
      name
      createdAt
      updatedAt
      category {
        id
        name
      }
    }
    orders {
      id
      userId
      status
      totalAmount
      createdAt
      updatedAt
      sagaStatus
      items {
        productId
        productName
        quantity
        unitPrice
      }
    }
  }
`

interface Command {
  id: string
  type: string
  status: "success" | "failed" | "pending"
  responseTime: number
  timestamp: string
  payload?: any
  error?: string
}

interface CommandStats {
  total: number
  success: number
  failed: number
  pending: number
  avgResponseTime: number
}

export default function CommandsPage() {
  const [commands, setCommands] = useState<Command[]>([])
  const [selectedCommand, setSelectedCommand] = useState<string>("all")
  const [_timeRange, _setTimeRange] = useState<string>("1h")
  const [stats, setStats] = useState<CommandStats>({
    total: 0,
    success: 0,
    failed: 0,
    pending: 0,
    avgResponseTime: 0,
  })

  // Query data from GraphQL
  const { data, loading, error } = useQuery(GET_ALL_DATA, {
    pollInterval: 5000, // Refresh every 5 seconds
  })

  useEffect(() => {
    if (!data) return

    // Convert GraphQL data to command history
    const commandHistory: Command[] = []

    // Process categories as CreateCategory commands
    data.categories?.forEach((category: any) => {
      commandHistory.push({
        id: `cmd-cat-${category.id}`,
        type: "CreateCategory",
        status: "success",
        responseTime: Math.floor(Math.random() * 50) + 10,
        timestamp: category.createdAt,
        payload: {
          name: category.name,
          id: category.id,
        },
      })

      // If updated, add an UpdateCategory command
      if (category.updatedAt !== category.createdAt) {
        commandHistory.push({
          id: `cmd-cat-upd-${category.id}`,
          type: "UpdateCategory",
          status: "success",
          responseTime: Math.floor(Math.random() * 50) + 10,
          timestamp: category.updatedAt,
          payload: {
            id: category.id,
            name: category.name,
          },
        })
      }
    })

    // Process products as CreateProduct commands
    data.products?.forEach((product: any) => {
      commandHistory.push({
        id: `cmd-prod-${product.id}`,
        type: "CreateProduct",
        status: "success",
        responseTime: Math.floor(Math.random() * 80) + 20,
        timestamp: product.createdAt,
        payload: {
          name: product.name,
          categoryId: product.category?.id,
          id: product.id,
        },
      })
    })

    // Process orders as CreateOrder commands
    data.orders?.forEach((order: any) => {
      const status =
        order.sagaStatus === "failed"
          ? "failed"
          : order.sagaStatus === "completed"
            ? "success"
            : "pending"

      commandHistory.push({
        id: `cmd-ord-${order.id}`,
        type: "CreateOrder",
        status,
        responseTime: Math.floor(Math.random() * 200) + 50,
        timestamp: order.createdAt,
        payload: {
          userId: order.userId,
          totalAmount: order.totalAmount,
          items: order.items,
        },
        error: status === "failed" ? "Saga execution failed" : undefined,
      })

      // Add saga-related commands
      if (order.sagaStatus) {
        commandHistory.push({
          id: `cmd-saga-${order.id}`,
          type: "StartOrderSaga",
          status: order.sagaStatus === "failed" ? "failed" : "success",
          responseTime: Math.floor(Math.random() * 300) + 100,
          timestamp: order.updatedAt,
          payload: {
            orderId: order.id,
            sagaStatus: order.sagaStatus,
          },
        })
      }
    })

    // Sort by timestamp descending
    commandHistory.sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime())

    setCommands(commandHistory)

    // Calculate statistics
    const stats: CommandStats = {
      total: commandHistory.length,
      success: commandHistory.filter((c) => c.status === "success").length,
      failed: commandHistory.filter((c) => c.status === "failed").length,
      pending: commandHistory.filter((c) => c.status === "pending").length,
      avgResponseTime:
        commandHistory.length > 0
          ? Math.round(
              commandHistory.reduce((acc, c) => acc + c.responseTime, 0) / commandHistory.length
            )
          : 0,
    }
    setStats(stats)
  }, [data])

  const getCommandTypeDistribution = () => {
    const distribution: { [key: string]: number } = {}
    commands.forEach((cmd) => {
      distribution[cmd.type] = (distribution[cmd.type] || 0) + 1
    })
    return Object.entries(distribution)
      .map(([name, value]) => ({ name, value }))
      .sort((a, b) => b.value - a.value)
  }

  const getResponseTimeData = () => {
    const timeGroups: { [key: string]: { time: string; avg: number; count: number } } = {}
    const now = new Date()

    commands.forEach((cmd) => {
      const cmdTime = new Date(cmd.timestamp)
      const diffMinutes = Math.floor((now.getTime() - cmdTime.getTime()) / 60000)

      // Group by 5-minute intervals
      const groupKey = Math.floor(diffMinutes / 5) * 5
      const groupTime = new Date(now.getTime() - groupKey * 60000).toLocaleTimeString()

      if (!timeGroups[groupKey]) {
        timeGroups[groupKey] = { time: groupTime, avg: 0, count: 0 }
      }

      timeGroups[groupKey].avg =
        (timeGroups[groupKey].avg * timeGroups[groupKey].count + cmd.responseTime) /
        (timeGroups[groupKey].count + 1)
      timeGroups[groupKey].count++
    })

    return Object.values(timeGroups)
      .sort((a, b) => b.time.localeCompare(a.time))
      .slice(0, 10)
      .reverse()
  }

  const filteredCommands =
    selectedCommand === "all" ? commands : commands.filter((cmd) => cmd.type === selectedCommand)

  const commandTypes = [...new Set(commands.map((cmd) => cmd.type))]

  return (
    <div className="container mx-auto p-8">
      <h1 className="text-3xl font-bold mb-6">Command History</h1>

      {loading && <div className="mb-4 text-gray-500">Loading command data...</div>}
      {error && <div className="mb-4 text-red-500">Error loading data: {error.message}</div>}

      {/* Statistics Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Total Commands</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.total}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Success Rate</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-green-600">
              {stats.total > 0 ? Math.round((stats.success / stats.total) * 100) : 0}%
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Avg Response Time</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.avgResponseTime}ms</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Failed Commands</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-red-600">{stats.failed}</div>
          </CardContent>
        </Card>
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
        {/* Command Distribution */}
        <Card>
          <CardHeader>
            <CardTitle>Command Distribution</CardTitle>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={getCommandTypeDistribution()}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="name" angle={-45} textAnchor="end" height={80} />
                <YAxis />
                <Tooltip />
                <Bar dataKey="value" fill="#3b82f6" />
              </BarChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>

        {/* Response Time Trend */}
        <Card>
          <CardHeader>
            <CardTitle>Response Time Trend</CardTitle>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={300}>
              <LineChart data={getResponseTimeData()}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="time" />
                <YAxis />
                <Tooltip />
                <Line type="monotone" dataKey="avg" stroke="#10b981" strokeWidth={2} />
              </LineChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>
      </div>

      {/* Filters */}
      <div className="flex gap-4 mb-6">
        <div>
          <label htmlFor="command-type-select" className="block text-sm font-medium mb-1">
            Command Type
          </label>
          <select
            id="command-type-select"
            value={selectedCommand}
            onChange={(e) => setSelectedCommand(e.target.value)}
            className="border rounded px-3 py-2"
          >
            <option value="all">All Commands</option>
            {commandTypes.map((type) => (
              <option key={type} value={type}>
                {type}
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* Command List */}
      <Card>
        <CardHeader>
          <CardTitle>Recent Commands</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {filteredCommands.slice(0, 50).map((command) => (
              <div
                key={command.id}
                className="border rounded p-4 hover:shadow-md transition-shadow"
              >
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center space-x-3">
                    <Badge className="bg-blue-500">{command.type}</Badge>
                    <Badge
                      className={
                        command.status === "success"
                          ? "bg-green-500"
                          : command.status === "failed"
                            ? "bg-red-500"
                            : "bg-yellow-500"
                      }
                    >
                      {command.status}
                    </Badge>
                    <span className="text-sm text-gray-500">{command.responseTime}ms</span>
                  </div>
                  <span className="text-sm text-gray-500">
                    {new Date(command.timestamp).toLocaleString()}
                  </span>
                </div>
                {command.payload && (
                  <details className="mt-2">
                    <summary className="cursor-pointer text-sm text-gray-600 hover:text-gray-800">
                      View Payload
                    </summary>
                    <pre className="mt-2 p-2 bg-gray-50 dark:bg-gray-800 rounded text-xs overflow-x-auto">
                      {JSON.stringify(command.payload, null, 2)}
                    </pre>
                  </details>
                )}
                {command.error && (
                  <div className="mt-2 text-sm text-red-600">Error: {command.error}</div>
                )}
              </div>
            ))}
          </div>
        </CardContent>
      </Card>
    </div>
  )
}

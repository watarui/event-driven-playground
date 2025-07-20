"use client"

import { gql, useQuery } from "@apollo/client"
import { Activity, AlertCircle, CheckCircle2, Database, RefreshCw, XCircle } from "lucide-react"
import { useEffect, useState } from "react"
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Legend,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts"
import { Badge } from "@/components/ui/badge"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"

// GraphQL queries for database statistics
const GET_EVENT_STORE_STATS = gql`
  query GetEventStoreStats {
    eventStoreStats {
      totalEvents
      eventsByType {
        eventType
        count
      }
      eventsByAggregate {
        aggregateType
        count
      }
      latestSequence
    }
  }
`

const GET_SYSTEM_STATISTICS = gql`
  query GetSystemStatistics {
    systemStatistics {
      eventStore {
        totalRecords
        lastUpdated
      }
      commandDb {
        totalRecords
        lastUpdated
      }
      queryDb {
        categories
        products
        orders
        lastUpdated
      }
      sagas {
        active
        completed
        failed
        compensated
        total
      }
    }
  }
`

interface EventTypeStats {
  eventType: string
  count: number
}

interface AggregateTypeStats {
  aggregateType: string
  count: number
}

interface EventStoreStats {
  totalEvents: number
  eventsByType: EventTypeStats[]
  eventsByAggregate: AggregateTypeStats[]
  latestSequence: number
}

interface SystemStatistics {
  eventStore: {
    totalRecords: number
    lastUpdated: string
  }
  commandDb: {
    totalRecords: number
    lastUpdated: string
  }
  queryDb: {
    categories: number
    products: number
    orders: number
    lastUpdated: string
  }
  sagas: {
    active: number
    completed: number
    failed: number
    compensated: number
    total: number
  }
}

const COLORS = ["#3B82F6", "#10B981", "#F59E0B", "#EF4444", "#8B5CF6", "#EC4899", "#6366F1"]

export default function DatabaseStatusPage() {
  const [lastRefreshed, setLastRefreshed] = useState(new Date())

  // Query Event Store statistics
  const {
    data: eventStoreData,
    loading: eventStoreLoading,
    error: eventStoreError,
    refetch: refetchEventStore,
  } = useQuery<{ eventStoreStats: EventStoreStats }>(GET_EVENT_STORE_STATS, {
    pollInterval: 10000, // Poll every 10 seconds
  })

  // Query System statistics
  const {
    data: systemData,
    loading: systemLoading,
    error: systemError,
    refetch: refetchSystem,
  } = useQuery<{ systemStatistics: SystemStatistics }>(GET_SYSTEM_STATISTICS, {
    pollInterval: 10000,
  })

  useEffect(() => {
    const interval = setInterval(() => {
      setLastRefreshed(new Date())
    }, 10000)
    return () => clearInterval(interval)
  }, [])

  const handleRefresh = async () => {
    setLastRefreshed(new Date())
    await Promise.all([refetchEventStore(), refetchSystem()])
  }

  const getSagaStatusData = () => {
    if (!systemData?.systemStatistics?.sagas) return []
    const { active, completed, failed, compensated } = systemData.systemStatistics.sagas
    return [
      { name: "Active", value: active, color: "#3B82F6" },
      { name: "Completed", value: completed, color: "#10B981" },
      { name: "Failed", value: failed, color: "#EF4444" },
      { name: "Compensated", value: compensated, color: "#F59E0B" },
    ].filter((item) => item.value > 0)
  }

  const getQueryDbData = () => {
    if (!systemData?.systemStatistics?.queryDb) return []
    const { categories, products, orders } = systemData.systemStatistics.queryDb
    return [
      { name: "Categories", value: categories },
      { name: "Products", value: products },
      { name: "Orders", value: orders },
    ]
  }

  const isLoading = eventStoreLoading || systemLoading
  const hasError = eventStoreError || systemError

  return (
    <div className="container mx-auto p-8">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-3xl font-bold">Database Status</h1>
        <div className="flex items-center gap-4">
          <span className="text-sm text-gray-500">
            Last updated: {lastRefreshed.toLocaleTimeString()}
          </span>
          <button
            onClick={handleRefresh}
            className="flex items-center gap-2 px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600 transition-colors"
            disabled={isLoading}
          >
            <RefreshCw className={`w-4 h-4 ${isLoading ? "animate-spin" : ""}`} />
            Refresh
          </button>
        </div>
      </div>

      {hasError && (
        <div className="mb-4 p-4 bg-red-50 dark:bg-red-900/20 text-red-600 dark:text-red-400 rounded">
          Error loading database statistics. Please check if all services are running.
        </div>
      )}

      {/* Database Overview */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        {/* Event Store Status */}
        <Card>
          <CardHeader className="pb-3">
            <div className="flex items-center justify-between">
              <CardTitle className="text-lg font-medium flex items-center gap-2">
                <Database className="w-5 h-5" />
                Event Store
              </CardTitle>
              <Badge className="bg-green-500">
                <CheckCircle2 className="w-3 h-3 mr-1" />
                Active
              </Badge>
            </div>
          </CardHeader>
          <CardContent>
            <div className="space-y-2">
              <div className="flex justify-between">
                <span className="text-sm text-gray-600 dark:text-gray-400">Total Events</span>
                <span className="font-semibold">
                  {eventStoreData?.eventStoreStats?.totalEvents || 0}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-sm text-gray-600 dark:text-gray-400">Latest Sequence</span>
                <span className="font-semibold">
                  {eventStoreData?.eventStoreStats?.latestSequence || 0}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-sm text-gray-600 dark:text-gray-400">Port</span>
                <span className="font-mono text-sm">5432</span>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Command DB Status */}
        <Card>
          <CardHeader className="pb-3">
            <div className="flex items-center justify-between">
              <CardTitle className="text-lg font-medium flex items-center gap-2">
                <Database className="w-5 h-5" />
                Command DB
              </CardTitle>
              <Badge className="bg-green-500">
                <CheckCircle2 className="w-3 h-3 mr-1" />
                Active
              </Badge>
            </div>
          </CardHeader>
          <CardContent>
            <div className="space-y-2">
              <div className="flex justify-between">
                <span className="text-sm text-gray-600 dark:text-gray-400">Total Records</span>
                <span className="font-semibold">
                  {systemData?.systemStatistics?.commandDb?.totalRecords || 0}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-sm text-gray-600 dark:text-gray-400">Port</span>
                <span className="font-mono text-sm">5433</span>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Query DB Status */}
        <Card>
          <CardHeader className="pb-3">
            <div className="flex items-center justify-between">
              <CardTitle className="text-lg font-medium flex items-center gap-2">
                <Database className="w-5 h-5" />
                Query DB
              </CardTitle>
              <Badge className="bg-green-500">
                <CheckCircle2 className="w-3 h-3 mr-1" />
                Active
              </Badge>
            </div>
          </CardHeader>
          <CardContent>
            <div className="space-y-2">
              <div className="flex justify-between">
                <span className="text-sm text-gray-600 dark:text-gray-400">Total Records</span>
                <span className="font-semibold">
                  {systemData?.systemStatistics?.queryDb
                    ? systemData.systemStatistics.queryDb.categories +
                      systemData.systemStatistics.queryDb.products +
                      systemData.systemStatistics.queryDb.orders
                    : 0}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-sm text-gray-600 dark:text-gray-400">Port</span>
                <span className="font-mono text-sm">5434</span>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Detailed Statistics */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Event Store Details */}
        <Card>
          <CardHeader>
            <CardTitle>Event Store - Event Types Distribution</CardTitle>
          </CardHeader>
          <CardContent>
            {eventStoreData?.eventStoreStats?.eventsByType &&
            eventStoreData.eventStoreStats.eventsByType.length > 0 ? (
              <ResponsiveContainer width="100%" height={300}>
                <BarChart data={eventStoreData.eventStoreStats.eventsByType}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="eventType" angle={-45} textAnchor="end" height={100} />
                  <YAxis />
                  <Tooltip />
                  <Bar dataKey="count" fill="#3B82F6" />
                </BarChart>
              </ResponsiveContainer>
            ) : (
              <div className="h-[300px] flex items-center justify-center text-gray-500">
                No event data available
              </div>
            )}
          </CardContent>
        </Card>

        {/* SAGA Status */}
        <Card>
          <CardHeader>
            <CardTitle>SAGA Execution Status</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex items-center justify-between mb-4">
              <span className="text-sm text-gray-600 dark:text-gray-400">
                Total SAGAs: {systemData?.systemStatistics?.sagas?.total || 0}
              </span>
            </div>
            {getSagaStatusData().length > 0 ? (
              <ResponsiveContainer width="100%" height={250}>
                <PieChart>
                  <Pie
                    data={getSagaStatusData()}
                    dataKey="value"
                    nameKey="name"
                    cx="50%"
                    cy="50%"
                    outerRadius={80}
                    label={({ name, value }) => `${name}: ${value}`}
                  >
                    {getSagaStatusData().map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={entry.color} />
                    ))}
                  </Pie>
                  <Tooltip />
                  <Legend />
                </PieChart>
              </ResponsiveContainer>
            ) : (
              <div className="h-[250px] flex items-center justify-center text-gray-500">
                No SAGA data available
              </div>
            )}
          </CardContent>
        </Card>

        {/* Query DB Details */}
        <Card>
          <CardHeader>
            <CardTitle>Query DB - Data Distribution</CardTitle>
          </CardHeader>
          <CardContent>
            {getQueryDbData().length > 0 ? (
              <ResponsiveContainer width="100%" height={300}>
                <BarChart data={getQueryDbData()}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="name" />
                  <YAxis />
                  <Tooltip />
                  <Bar dataKey="value" fill="#10B981" />
                </BarChart>
              </ResponsiveContainer>
            ) : (
              <div className="h-[300px] flex items-center justify-center text-gray-500">
                No query data available
              </div>
            )}
          </CardContent>
        </Card>

        {/* Aggregate Types Distribution */}
        <Card>
          <CardHeader>
            <CardTitle>Event Store - Aggregate Types</CardTitle>
          </CardHeader>
          <CardContent>
            {eventStoreData?.eventStoreStats?.eventsByAggregate &&
            eventStoreData.eventStoreStats.eventsByAggregate.length > 0 ? (
              <div className="space-y-3">
                {eventStoreData.eventStoreStats.eventsByAggregate.map((aggregate, index) => (
                  <div key={aggregate.aggregateType} className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <div
                        className="w-3 h-3 rounded-full"
                        style={{ backgroundColor: COLORS[index % COLORS.length] }}
                      />
                      <span className="font-medium">{aggregate.aggregateType}</span>
                    </div>
                    <span className="font-mono">{aggregate.count}</span>
                  </div>
                ))}
              </div>
            ) : (
              <div className="h-[200px] flex items-center justify-center text-gray-500">
                No aggregate data available
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}

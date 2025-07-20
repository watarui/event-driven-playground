"use client"

import { useQuery, useSubscription } from "@apollo/client"
import { motion } from "framer-motion"
import {
  Activity,
  Code,
  Database,
  GitBranch,
  MessageSquare,
  Pause,
  Play,
  RefreshCw,
  Search,
} from "lucide-react"
import Link from "next/link"
import { useEffect, useState } from "react"
import { EventStream } from "@/components/event-stream"
import { FlowVisualization } from "@/components/flow-visualization"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { config } from "@/lib/config"
import {
  DASHBOARD_OVERVIEW,
  DASHBOARD_STATS_SUBSCRIPTION,
  EVENT_STREAM_SUBSCRIPTION,
} from "@/lib/graphql/queries/dashboard"

export default function Home() {
  const [isPaused, setIsPaused] = useState(false)
  const [events, setEvents] = useState<any[]>([])
  const [flowMessages, setFlowMessages] = useState<any[]>([])

  const { data, loading, error, refetch } = useQuery(DASHBOARD_OVERVIEW, {
    pollInterval: isPaused ? 0 : 5000,
  })

  const { data: eventStreamData } = useSubscription(EVENT_STREAM_SUBSCRIPTION, {
    skip: isPaused,
  })

  const { data: statsStreamData } = useSubscription(DASHBOARD_STATS_SUBSCRIPTION, {
    skip: isPaused,
  })

  // イベントストリームを処理
  useEffect(() => {
    if (eventStreamData?.eventStream) {
      const event = eventStreamData.eventStream
      const streamEvent = {
        id: event.id,
        type: "event" as const,
        name: event.eventType,
        service: event.aggregateType,
        timestamp: event.insertedAt,
        data: event.eventData,
        status: "success" as const,
      }

      setEvents((prev) => [streamEvent, ...prev].slice(0, 100))

      // フローメッセージも生成
      const flowMessage = {
        id: event.id,
        from: "command",
        to: "eventstore",
        type: "event" as const,
        data: event.eventData,
      }
      setFlowMessages((prev) => [...prev, flowMessage])
    }
  }, [eventStreamData])

  // 初期データの設定
  useEffect(() => {
    if (data?.recentEvents) {
      const initialEvents = data.recentEvents.map((event: any) => ({
        id: event.id,
        type: "event" as const,
        name: event.eventType,
        service: event.aggregateType,
        timestamp: event.insertedAt,
        data: event.eventData,
        status: "success" as const,
      }))
      setEvents(initialEvents)
    }
  }, [data])

  const dashboardStats = statsStreamData?.dashboardStatsStream || data?.dashboardStats || {}
  const systemStats = data?.systemStatistics || {}
  const eventStoreStats = data?.eventStoreStats || {}

  // メトリクスデータの準備
  const _metrics = {
    cpu: 45 + Math.random() * 20,
    memory: 62 + Math.random() * 15,
    latency: dashboardStats.averageLatencyMs || 23,
    throughput: dashboardStats.eventsPerMinute * 20 || 1250,
    errorRate: dashboardStats.errorRate * 100 || 0.2,
    activeConnections: 89,
    history: {
      throughput: Array.from({ length: 20 }, (_, i) => ({
        time: `${i}`,
        value: 1000 + Math.random() * 500,
      })),
      latency: Array.from({ length: 20 }, (_, i) => ({
        time: `${i}`,
        value: 20 + Math.random() * 10,
      })),
      errorRate: Array.from({ length: 20 }, (_, i) => ({
        time: `${i}`,
        value: Math.random() * 2,
      })),
    },
  }

  if (loading && !data) {
    return (
      <div className="container mx-auto p-8">
        <div className="flex items-center justify-center h-screen">
          <div className="text-lg">Loading CQRS/ES Dashboard...</div>
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="container mx-auto p-8">
        <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded">
          Error: {error.message}
        </div>
      </div>
    )
  }

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ duration: 0.5 }}
      className="container mx-auto p-4 lg:p-8 space-y-6"
    >
      {/* ヘッダー */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">CQRS/ES Real-time Dashboard</h1>
          <p className="text-muted-foreground mt-1">
            Visualizing event flows and system state in real-time
          </p>
        </div>
        <div className="flex items-center gap-4">
          <Badge variant={dashboardStats.systemHealth === "healthy" ? "default" : "destructive"}>
            System {dashboardStats.systemHealth || "Unknown"}
          </Badge>
          <Button onClick={() => setIsPaused(!isPaused)} variant="outline" size="sm">
            {isPaused ? <Play className="w-4 h-4 mr-2" /> : <Pause className="w-4 h-4 mr-2" />}
            {isPaused ? "Resume" : "Pause"}
          </Button>
          <Button onClick={() => refetch()} variant="outline" size="sm">
            <RefreshCw className="w-4 h-4 mr-2" />
            Refresh
          </Button>
        </div>
      </div>

      {/* メインコンテンツ */}
      <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
        {/* システムトポロジー（中央） */}
        <div className="xl:col-span-2">
          <Card>
            <CardHeader>
              <CardTitle>System Topology & Data Flow</CardTitle>
            </CardHeader>
            <CardContent>
              <FlowVisualization messages={flowMessages} />
            </CardContent>
          </Card>
        </div>

        {/* イベントストリーム（右） */}
        <div className="xl:col-span-1">
          <EventStream events={events} title="Live Event Stream" />
        </div>
      </div>

      {/* 詳細タブ */}
      <Card>
        <CardContent className="pt-6">
          <Tabs defaultValue="overview" className="w-full">
            <TabsList className="grid w-full grid-cols-4">
              <TabsTrigger value="overview">Overview</TabsTrigger>
              <TabsTrigger value="events">Events</TabsTrigger>
              <TabsTrigger value="sagas">SAGAs</TabsTrigger>
              <TabsTrigger value="performance">Performance</TabsTrigger>
            </TabsList>

            <TabsContent value="overview" className="mt-6">
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                <StatsCard
                  title="Total Events"
                  value={eventStoreStats.totalEvents || 0}
                  icon={<Database className="w-5 h-5" />}
                  trend={`+${dashboardStats.eventsPerMinute || 0}/min`}
                />
                <StatsCard
                  title="Active SAGAs"
                  value={systemStats.sagas?.active || 0}
                  icon={<GitBranch className="w-5 h-5" />}
                  trend={`${systemStats.sagas?.total || 0} total`}
                />
                <StatsCard
                  title="Commands"
                  value={dashboardStats.totalCommands || 0}
                  icon={<Activity className="w-5 h-5" />}
                  trend={`${dashboardStats.averageLatencyMs || 0}ms avg`}
                />
                <StatsCard
                  title="Queries"
                  value={dashboardStats.totalQueries || 0}
                  icon={<MessageSquare className="w-5 h-5" />}
                  trend={`${(dashboardStats.errorRate * 100).toFixed(1)}% error`}
                />
              </div>
            </TabsContent>

            <TabsContent value="events" className="mt-6">
              <div className="space-y-4">
                <h3 className="text-lg font-semibold">Event Distribution</h3>
                <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                  {eventStoreStats.eventsByType?.slice(0, 8).map((item: any) => (
                    <div key={item.eventType} className="p-4 border rounded-lg">
                      <div className="text-sm text-muted-foreground">{item.eventType}</div>
                      <div className="text-2xl font-bold">{item.count}</div>
                    </div>
                  ))}
                </div>
              </div>
            </TabsContent>

            <TabsContent value="sagas" className="mt-6">
              <div className="space-y-4">
                <h3 className="text-lg font-semibold">SAGA Statistics</h3>
                <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                  <div className="p-4 border rounded-lg bg-blue-50 dark:bg-blue-950/20">
                    <div className="text-sm text-muted-foreground">Active</div>
                    <div className="text-2xl font-bold text-blue-600">
                      {systemStats.sagas?.active || 0}
                    </div>
                  </div>
                  <div className="p-4 border rounded-lg bg-green-50 dark:bg-green-950/20">
                    <div className="text-sm text-muted-foreground">Completed</div>
                    <div className="text-2xl font-bold text-green-600">
                      {systemStats.sagas?.completed || 0}
                    </div>
                  </div>
                  <div className="p-4 border rounded-lg bg-red-50 dark:bg-red-950/20">
                    <div className="text-sm text-muted-foreground">Failed</div>
                    <div className="text-2xl font-bold text-red-600">
                      {systemStats.sagas?.failed || 0}
                    </div>
                  </div>
                  <div className="p-4 border rounded-lg bg-yellow-50 dark:bg-yellow-950/20">
                    <div className="text-sm text-muted-foreground">Compensated</div>
                    <div className="text-2xl font-bold text-yellow-600">
                      {systemStats.sagas?.compensated || 0}
                    </div>
                  </div>
                </div>
              </div>
            </TabsContent>

            <TabsContent value="performance" className="mt-6">
              <div className="space-y-4">
                <h3 className="text-lg font-semibold">System Performance</h3>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                  <div className="p-4 border rounded-lg">
                    <h4 className="font-medium mb-2">Event Store</h4>
                    <div className="space-y-2 text-sm">
                      <div className="flex justify-between">
                        <span className="text-muted-foreground">Total Records</span>
                        <span>{systemStats.eventStore?.totalRecords || 0}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-muted-foreground">Latest Sequence</span>
                        <span>{eventStoreStats.latestSequence || 0}</span>
                      </div>
                    </div>
                  </div>
                  <div className="p-4 border rounded-lg">
                    <h4 className="font-medium mb-2">Command DB</h4>
                    <div className="space-y-2 text-sm">
                      <div className="flex justify-between">
                        <span className="text-muted-foreground">Total Records</span>
                        <span>{systemStats.commandDb?.totalRecords || 0}</span>
                      </div>
                    </div>
                  </div>
                  <div className="p-4 border rounded-lg">
                    <h4 className="font-medium mb-2">Query DB</h4>
                    <div className="space-y-2 text-sm">
                      <div className="flex justify-between">
                        <span className="text-muted-foreground">Categories</span>
                        <span>{systemStats.queryDb?.categories || 0}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-muted-foreground">Products</span>
                        <span>{systemStats.queryDb?.products || 0}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-muted-foreground">Orders</span>
                        <span>{systemStats.queryDb?.orders || 0}</span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </TabsContent>
          </Tabs>
        </CardContent>
      </Card>

      {/* クイックアクセス */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <QuickAccessCard
          href="/sagas"
          title="SAGA Monitor"
          description="Track SAGA orchestration"
          icon={<GitBranch className="w-6 h-6" />}
        />
        <QuickAccessCard
          href="/events"
          title="Event Store"
          description="Browse event history"
          icon={<Database className="w-6 h-6" />}
        />
        <QuickAccessCard
          href="/pubsub"
          title="PubSub Monitor"
          description="Real-time messages"
          icon={<MessageSquare className="w-6 h-6" />}
        />
        <QuickAccessCard
          href="/topology"
          title="System Map"
          description="Service topology"
          icon={<Activity className="w-6 h-6" />}
        />
      </div>

      {/* 外部ツール */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {/* データベースビューア */}
        <Card>
          <CardHeader>
            <CardTitle>Database Viewers</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <a href={config.databases.eventStore} target="_blank" rel="noopener noreferrer">
                <motion.div
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  className="p-4 border rounded-lg hover:shadow-lg transition-all cursor-pointer"
                >
                  <div className="flex items-center space-x-3">
                    <Database className="w-5 h-5 text-blue-500" />
                    <div>
                      <h4 className="font-medium">Event Store</h4>
                      <p className="text-sm text-muted-foreground">Port 5050</p>
                    </div>
                  </div>
                </motion.div>
              </a>
              <a href={config.databases.commandDb} target="_blank" rel="noopener noreferrer">
                <motion.div
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  className="p-4 border rounded-lg hover:shadow-lg transition-all cursor-pointer"
                >
                  <div className="flex items-center space-x-3">
                    <Database className="w-5 h-5 text-green-500" />
                    <div>
                      <h4 className="font-medium">Command DB</h4>
                      <p className="text-sm text-muted-foreground">Port 5051</p>
                    </div>
                  </div>
                </motion.div>
              </a>
              <a href={config.databases.queryDb} target="_blank" rel="noopener noreferrer">
                <motion.div
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  className="p-4 border rounded-lg hover:shadow-lg transition-all cursor-pointer"
                >
                  <div className="flex items-center space-x-3">
                    <Database className="w-5 h-5 text-purple-500" />
                    <div>
                      <h4 className="font-medium">Query DB</h4>
                      <p className="text-sm text-muted-foreground">Port 5052</p>
                    </div>
                  </div>
                </motion.div>
              </a>
            </div>
          </CardContent>
        </Card>

        {/* 開発ツール */}
        <Card>
          <CardHeader>
            <CardTitle>Development Tools</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <a href="/graphiql" target="_blank" rel="noopener noreferrer">
                <motion.div
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  className="p-4 border rounded-lg hover:shadow-lg transition-all cursor-pointer"
                >
                  <div className="flex items-center space-x-3">
                    <Code className="w-5 h-5 text-pink-500" />
                    <div>
                      <h4 className="font-medium">GraphiQL</h4>
                      <p className="text-sm text-muted-foreground">GraphQL Playground</p>
                    </div>
                  </div>
                </motion.div>
              </a>
              <a href={config.external.jaeger} target="_blank" rel="noopener noreferrer">
                <motion.div
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  className="p-4 border rounded-lg hover:shadow-lg transition-all cursor-pointer"
                >
                  <div className="flex items-center space-x-3">
                    <Search className="w-5 h-5 text-orange-500" />
                    <div>
                      <h4 className="font-medium">Jaeger UI</h4>
                      <p className="text-sm text-muted-foreground">Distributed Tracing</p>
                    </div>
                  </div>
                </motion.div>
              </a>
            </div>
          </CardContent>
        </Card>
      </div>
    </motion.div>
  )
}

function StatsCard({ title, value, icon, trend }: any) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      whileHover={{ scale: 1.02 }}
      transition={{ duration: 0.2 }}
    >
      <Card>
        <CardContent className="p-6">
          <div className="flex items-center justify-between">
            <div className="space-y-1">
              <p className="text-sm text-muted-foreground">{title}</p>
              <p className="text-2xl font-bold">{value}</p>
              <p className="text-xs text-muted-foreground">{trend}</p>
            </div>
            <div className="p-3 bg-primary/10 rounded-lg">{icon}</div>
          </div>
        </CardContent>
      </Card>
    </motion.div>
  )
}

function QuickAccessCard({ href, title, description, icon }: any) {
  return (
    <Link href={href}>
      <motion.div
        whileHover={{ scale: 1.05 }}
        whileTap={{ scale: 0.95 }}
        className="p-6 border rounded-lg hover:shadow-lg transition-all cursor-pointer"
      >
        <div className="flex items-start space-x-4">
          <div className="p-3 bg-primary/10 rounded-lg">{icon}</div>
          <div>
            <h3 className="font-semibold">{title}</h3>
            <p className="text-sm text-muted-foreground mt-1">{description}</p>
          </div>
        </div>
      </motion.div>
    </Link>
  )
}

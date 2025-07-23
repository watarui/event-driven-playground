"use client"

import { useQuery, useSubscription } from "@apollo/client"
import { Activity, Filter, Pause, Play, RefreshCw, TrendingUp } from "lucide-react"
import { useEffect, useRef, useState } from "react"
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
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import {
  DASHBOARD_STATS,
  LIST_PUBSUB_MESSAGES,
  PUBSUB_MESSAGE_STREAM,
  PUBSUB_STATS,
} from "@/lib/graphql/queries/pubsub"

interface PubSubMessage {
  id: string
  topic: string
  messageType: string
  payload: any
  timestamp: string
  sourceService?: string
}

interface TopicStat {
  topic: string
  messageCount: number
  messagesPerMinute: number
  lastMessageAt?: string
}

export default function PubSubPage() {
  const [messages, setMessages] = useState<PubSubMessage[]>([])
  const [selectedTopic, setSelectedTopic] = useState<string>("all")
  const [searchTerm, setSearchTerm] = useState<string>("")
  const [isPaused, setIsPaused] = useState(false)
  const [messageHistory, setMessageHistory] = useState<Array<{ time: string; count: number }>>([])
  const messagesEndRef = useRef<HTMLDivElement>(null)

  // 履歴データの取得
  const {
    data: historyData,
    loading: historyLoading,
    refetch,
  } = useQuery(LIST_PUBSUB_MESSAGES, {
    variables: {
      limit: 100,
      topic: selectedTopic === "all" ? null : selectedTopic,
    },
    skip: isPaused,
  })

  // 統計データの取得
  const { data: statsData } = useQuery(PUBSUB_STATS, {
    pollInterval: 5000,
    skip: isPaused,
  })

  // ダッシュボード統計の取得
  const { data: dashboardData } = useQuery(DASHBOARD_STATS, {
    pollInterval: 5000,
  })

  // リアルタイムメッセージのサブスクリプション
  const { data: streamData } = useSubscription(PUBSUB_MESSAGE_STREAM, {
    variables: {
      topic: selectedTopic === "all" ? null : selectedTopic,
    },
    skip: isPaused,
  })

  // 履歴データの初期化
  useEffect(() => {
    if (historyData?.pubsubMessages) {
      setMessages(historyData.pubsubMessages)
    }
  }, [historyData])

  // ストリーミングデータの追加
  useEffect(() => {
    if (streamData?.pubsubStream && !isPaused) {
      const newMessage = streamData.pubsubStream
      setMessages((prev) => {
        const updated = [...prev, newMessage]
        // 最大500メッセージを保持
        return updated.slice(-500)
      })
    }
  }, [streamData, isPaused])

  // メッセージ履歴グラフの更新
  useEffect(() => {
    const interval = setInterval(() => {
      if (!isPaused) {
        const now = new Date()
        const recentMessages = messages.filter((m) => {
          const msgTime = new Date(m.timestamp)
          return now.getTime() - msgTime.getTime() < 60000 // 1分以内
        })

        setMessageHistory((prev) => {
          const updated = [
            ...prev,
            {
              time: now.toLocaleTimeString(),
              count: recentMessages.length,
            },
          ]
          // 最大20ポイントを保持
          return updated.slice(-20)
        })
      }
    }, 3000) // 3秒ごとに更新

    return () => clearInterval(interval)
  }, [messages, isPaused])

  // 自動スクロール
  useEffect(() => {
    if (!isPaused && messagesEndRef.current) {
      const container = messagesEndRef.current.parentElement
      if (container) {
        const { scrollHeight, scrollTop, clientHeight } = container
        const isNearBottom = scrollHeight - scrollTop - clientHeight < 100
        if (isNearBottom) {
          container.scrollTop = scrollHeight
        }
      }
    }
  }, [isPaused])

  const getTopicColor = (topic: string) => {
    const colors: { [key: string]: string } = {
      events: "bg-blue-500",
      commands: "bg-green-500",
      queries: "bg-purple-500",
      sagas: "bg-orange-500",
      system: "bg-gray-500",
    }

    const topicType = topic.split(":")[0]
    return colors[topicType] || "bg-gray-400"
  }

  const getTopicIcon = (topic: string) => {
    if (topic.includes("events")) return "📨"
    if (topic.includes("commands")) return "⚡"
    if (topic.includes("queries")) return "🔍"
    if (topic.includes("sagas")) return "🔄"
    return "📌"
  }

  const filteredMessages = messages.filter((m) => {
    const matchesTopic = selectedTopic === "all" || m.topic === selectedTopic
    const matchesSearch =
      !searchTerm ||
      JSON.stringify(m.payload).toLowerCase().includes(searchTerm.toLowerCase()) ||
      m.messageType.toLowerCase().includes(searchTerm.toLowerCase())
    return matchesTopic && matchesSearch
  })

  const topicStats = statsData?.pubsubStats || []
  const dashboardStats = dashboardData?.dashboardStats || {}

  const isConnected = !historyLoading && !historyData?.error

  // トピック別メッセージ数のデータ準備
  const topicChartData = topicStats.slice(0, 10).map((stat: TopicStat) => ({
    topic: stat.topic.split(":").pop() || stat.topic,
    count: stat.messageCount,
    rate: stat.messagesPerMinute,
  }))

  return (
    <div className="container mx-auto p-8">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-3xl font-bold">PubSub Monitor</h1>
        <div className="flex items-center space-x-4">
          <Badge className={isConnected ? "bg-green-500" : "bg-red-500"}>
            {isConnected ? "Connected" : "Disconnected"}
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

      {/* 統計カード */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium flex items-center">
              <Activity className="w-4 h-4 mr-2" />
              Events/Min
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-blue-600">
              {dashboardStats.eventsPerMinute?.toFixed(1) || 0}
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Active Topics</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{topicStats.length}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Total Messages</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {topicStats.reduce((sum: number, stat: TopicStat) => sum + stat.messageCount, 0)}
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium flex items-center">
              <TrendingUp className="w-4 h-4 mr-2" />
              Peak Topic
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-sm font-bold truncate">{topicStats[0]?.topic || "N/A"}</div>
            <div className="text-xs text-gray-500">
              {topicStats[0]?.messagesPerMinute.toFixed(1)} msg/min
            </div>
          </CardContent>
        </Card>
      </div>

      {/* グラフ */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
        <Card>
          <CardHeader>
            <CardTitle>Message Rate (Last 1 min)</CardTitle>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={200}>
              <LineChart data={messageHistory}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="time" />
                <YAxis />
                <Tooltip />
                <Line type="monotone" dataKey="count" stroke="#3B82F6" strokeWidth={2} />
              </LineChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Top Topics by Volume</CardTitle>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={200}>
              <BarChart data={topicChartData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="topic" angle={-45} textAnchor="end" height={60} />
                <YAxis />
                <Tooltip />
                <Bar dataKey="count" fill="#10B981" />
              </BarChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>
      </div>

      {/* フィルター */}
      <div className="flex space-x-4 mb-6">
        <Select value={selectedTopic} onValueChange={setSelectedTopic}>
          <SelectTrigger className="w-[250px]">
            <SelectValue placeholder="Filter by topic" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All Topics</SelectItem>
            {topicStats.map((stat: TopicStat) => (
              <SelectItem key={stat.topic} value={stat.topic}>
                {getTopicIcon(stat.topic)} {stat.topic} ({stat.messageCount})
              </SelectItem>
            ))}
          </SelectContent>
        </Select>

        <Input
          placeholder="Search in messages..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          className="max-w-xs"
          icon={<Filter className="w-4 h-4" />}
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* トピック統計 */}
        <Card className="lg:col-span-1">
          <CardHeader>
            <CardTitle>Topic Statistics</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-2 max-h-[600px] overflow-y-auto">
              {topicStats.map((stat: TopicStat) => (
                <button
                  type="button"
                  key={stat.topic}
                  className={`w-full flex items-center justify-between p-3 rounded hover:bg-gray-100 dark:hover:bg-gray-800 cursor-pointer transition-colors ${
                    selectedTopic === stat.topic ? "bg-gray-100 dark:bg-gray-800" : ""
                  }`}
                  onClick={() => setSelectedTopic(stat.topic)}
                >
                  <div className="flex items-center space-x-3 flex-1 min-w-0">
                    <div
                      className={`w-3 h-3 rounded-full flex-shrink-0 ${getTopicColor(stat.topic)}`}
                    />
                    <div className="flex-1 min-w-0">
                      <div className="text-sm font-mono truncate">{stat.topic}</div>
                      <div className="text-xs text-gray-500">
                        {stat.messagesPerMinute.toFixed(1)} msg/min
                      </div>
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="text-sm font-semibold">{stat.messageCount}</div>
                    {stat.lastMessageAt && (
                      <div className="text-xs text-gray-500">
                        {new Date(stat.lastMessageAt).toLocaleTimeString()}
                      </div>
                    )}
                  </div>
                </button>
              ))}
            </div>
          </CardContent>
        </Card>

        {/* メッセージストリーム */}
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle>
              Message Stream
              <span className="text-sm font-normal text-gray-500 ml-2">
                ({filteredMessages.length} messages)
              </span>
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-2 max-h-[600px] overflow-y-auto">
              {filteredMessages.length === 0 ? (
                <div className="text-center py-8 text-gray-500">No messages to display</div>
              ) : (
                filteredMessages
                  .slice(-100)
                  .reverse()
                  .map((message) => (
                    <div
                      key={message.id}
                      className="border rounded-lg p-3 hover:shadow-md transition-shadow"
                    >
                      <div className="flex items-center justify-between mb-2">
                        <div className="flex items-center space-x-2">
                          <Badge className={`${getTopicColor(message.topic)} text-white`}>
                            {getTopicIcon(message.topic)} {message.topic}
                          </Badge>
                          <Badge variant="outline">{message.messageType}</Badge>
                          {message.sourceService && (
                            <span className="text-xs text-gray-500">
                              from {message.sourceService}
                            </span>
                          )}
                        </div>
                        <span className="text-xs text-gray-500">
                          {new Date(message.timestamp).toLocaleTimeString("en-US", {
                            hour12: false,
                            hour: "2-digit",
                            minute: "2-digit",
                            second: "2-digit",
                            fractionalSecondDigits: 3,
                          })}
                        </span>
                      </div>
                      <pre className="mt-2 p-2 bg-gray-50 dark:bg-gray-800 rounded text-xs overflow-x-auto">
                        {JSON.stringify(message.payload, null, 2)}
                      </pre>
                    </div>
                  ))
              )}
              <div ref={messagesEndRef} />
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}

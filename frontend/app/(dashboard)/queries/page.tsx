"use client"

import { useEffect, useState } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { PieChart, Pie, LineChart, Line, Cell, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend } from "recharts"
import { useQuery, gql } from "@apollo/client"

// GraphQL introspection query to get available queries
const GET_QUERY_DATA = gql`
  query GetQueryData {
    categories {
      id
      name
      description
      active
      products {
        id
      }
    }
    products {
      id
      name
      price
      stockQuantity
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
      items {
        productId
        quantity
      }
    }
  }
`

interface QueryExecution {
  id: string
  queryType: string
  responseTime: number
  cacheHit: boolean
  timestamp: string
  dataSize: number
  filters?: any
  result?: any
}

interface QueryStats {
  total: number
  cacheHits: number
  cacheMisses: number
  avgResponseTime: number
  queryTypes: number
}

interface QueryTypeStats {
  name: string
  count: number
  avgResponseTime: number
  cacheHitRate: number
}

export default function QueriesPage() {
  const [queries, setQueries] = useState<QueryExecution[]>([])
  const [selectedQueryType, setSelectedQueryType] = useState<string>("all")
  const [stats, setStats] = useState<QueryStats>({
    total: 0,
    cacheHits: 0,
    cacheMisses: 0,
    avgResponseTime: 0,
    queryTypes: 0,
  })
  const [queryTypeStats, setQueryTypeStats] = useState<QueryTypeStats[]>([])

  // Query data from GraphQL
  const { data, loading, error, refetch } = useQuery(GET_QUERY_DATA, {
    pollInterval: 10000, // Refresh every 10 seconds
    fetchPolicy: 'network-only', // Always fetch fresh data
  })

  useEffect(() => {
    // Simulate query execution history based on data fetches
    const queryHistory: QueryExecution[] = []
    const now = new Date()

    // Track our actual GraphQL queries
    queryHistory.push({
      id: `qry-${Date.now()}-1`,
      queryType: "GetQueryData",
      responseTime: Math.floor(Math.random() * 100) + 20,
      cacheHit: Math.random() > 0.3,
      timestamp: now.toISOString(),
      dataSize: JSON.stringify(data || {}).length,
      result: data
    })

    // Add simulated individual query executions based on the data
    if (data?.categories) {
      // Simulate GetCategories queries
      for (let i = 0; i < 5; i++) {
        const timestamp = new Date(now.getTime() - i * 60000 * 5)
        queryHistory.push({
          id: `qry-cat-${i}`,
          queryType: "GetCategories",
          responseTime: Math.floor(Math.random() * 50) + 10,
          cacheHit: Math.random() > 0.4,
          timestamp: timestamp.toISOString(),
          dataSize: JSON.stringify(data.categories).length,
          filters: { active: true }
        })
      }

      // Simulate GetCategoryById queries
      data.categories.forEach((category: any, index: number) => {
        const timestamp = new Date(now.getTime() - index * 60000 * 2)
        queryHistory.push({
          id: `qry-cat-by-id-${category.id}`,
          queryType: "GetCategoryById",
          responseTime: Math.floor(Math.random() * 30) + 5,
          cacheHit: Math.random() > 0.2,
          timestamp: timestamp.toISOString(),
          dataSize: JSON.stringify(category).length,
          filters: { id: category.id }
        })
      })
    }

    if (data?.products) {
      // Simulate GetProducts queries
      for (let i = 0; i < 8; i++) {
        const timestamp = new Date(now.getTime() - i * 60000 * 3)
        queryHistory.push({
          id: `qry-prod-${i}`,
          queryType: "GetProducts",
          responseTime: Math.floor(Math.random() * 80) + 20,
          cacheHit: Math.random() > 0.5,
          timestamp: timestamp.toISOString(),
          dataSize: JSON.stringify(data.products).length,
          filters: { 
            category: i % 2 === 0 ? "Electronics" : undefined,
            inStock: true 
          }
        })
      }

      // Simulate SearchProducts queries
      const searchTerms = ["Mac", "iPhone", "Pro", "Air", "Watch"]
      searchTerms.forEach((term, index) => {
        const timestamp = new Date(now.getTime() - index * 60000 * 7)
        queryHistory.push({
          id: `qry-search-${index}`,
          queryType: "SearchProducts",
          responseTime: Math.floor(Math.random() * 120) + 30,
          cacheHit: Math.random() > 0.7,
          timestamp: timestamp.toISOString(),
          dataSize: Math.floor(Math.random() * 5000) + 500,
          filters: { searchTerm: term }
        })
      })
    }

    if (data?.orders) {
      // Simulate GetOrders queries
      for (let i = 0; i < 6; i++) {
        const timestamp = new Date(now.getTime() - i * 60000 * 4)
        queryHistory.push({
          id: `qry-ord-${i}`,
          queryType: "GetOrders",
          responseTime: Math.floor(Math.random() * 150) + 50,
          cacheHit: Math.random() > 0.6,
          timestamp: timestamp.toISOString(),
          dataSize: JSON.stringify(data.orders).length,
          filters: { 
            status: ["pending", "completed", "processing"][i % 3],
            limit: 10 
          }
        })
      }

      // Simulate GetUserOrders queries
      const userIds = ["user_001", "user_002", "user_003"]
      userIds.forEach((userId, index) => {
        const timestamp = new Date(now.getTime() - index * 60000 * 8)
        queryHistory.push({
          id: `qry-user-ord-${index}`,
          queryType: "GetUserOrders",
          responseTime: Math.floor(Math.random() * 100) + 25,
          cacheHit: Math.random() > 0.4,
          timestamp: timestamp.toISOString(),
          dataSize: Math.floor(Math.random() * 3000) + 200,
          filters: { userId }
        })
      })
    }

    // Sort by timestamp descending
    queryHistory.sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime())
    setQueries(queryHistory)

    // Calculate statistics
    const stats: QueryStats = {
      total: queryHistory.length,
      cacheHits: queryHistory.filter(q => q.cacheHit).length,
      cacheMisses: queryHistory.filter(q => !q.cacheHit).length,
      avgResponseTime: queryHistory.length > 0
        ? Math.round(queryHistory.reduce((acc, q) => acc + q.responseTime, 0) / queryHistory.length)
        : 0,
      queryTypes: new Set(queryHistory.map(q => q.queryType)).size
    }
    setStats(stats)

    // Calculate per-query-type statistics
    const typeStats: { [key: string]: { count: number, totalTime: number, cacheHits: number } } = {}
    queryHistory.forEach(query => {
      if (!typeStats[query.queryType]) {
        typeStats[query.queryType] = { count: 0, totalTime: 0, cacheHits: 0 }
      }
      typeStats[query.queryType].count++
      typeStats[query.queryType].totalTime += query.responseTime
      if (query.cacheHit) typeStats[query.queryType].cacheHits++
    })

    const queryTypeStatsArray: QueryTypeStats[] = Object.entries(typeStats).map(([name, stats]) => ({
      name,
      count: stats.count,
      avgResponseTime: Math.round(stats.totalTime / stats.count),
      cacheHitRate: Math.round((stats.cacheHits / stats.count) * 100)
    }))

    setQueryTypeStats(queryTypeStatsArray.sort((a, b) => b.count - a.count))

  }, [data])

  const getCachePerformanceData = () => [
    { name: "Cache Hits", value: stats.cacheHits, color: "#10b981" },
    { name: "Cache Misses", value: stats.cacheMisses, color: "#ef4444" }
  ]

  const getResponseTimeData = () => {
    const timeGroups: { [key: string]: { time: string, avg: number, count: number } } = {}
    const now = new Date()

    queries.forEach(query => {
      const queryTime = new Date(query.timestamp)
      const diffMinutes = Math.floor((now.getTime() - queryTime.getTime()) / 60000)
      
      // Group by 10-minute intervals
      const groupKey = Math.floor(diffMinutes / 10) * 10
      const groupTime = new Date(now.getTime() - groupKey * 60000).toLocaleTimeString()
      
      if (!timeGroups[groupKey]) {
        timeGroups[groupKey] = { time: groupTime, avg: 0, count: 0 }
      }
      
      timeGroups[groupKey].avg = 
        (timeGroups[groupKey].avg * timeGroups[groupKey].count + query.responseTime) / 
        (timeGroups[groupKey].count + 1)
      timeGroups[groupKey].count++
    })

    return Object.values(timeGroups)
      .sort((a, b) => b.time.localeCompare(a.time))
      .slice(0, 6)
      .reverse()
  }

  const filteredQueries = selectedQueryType === "all"
    ? queries
    : queries.filter(q => q.queryType === selectedQueryType)

  const queryTypes = [...new Set(queries.map(q => q.queryType))]

  return (
    <div className="container mx-auto p-8">
      <h1 className="text-3xl font-bold mb-6">Query Analytics</h1>

      {loading && <div className="mb-4 text-gray-500">Loading query data...</div>}
      {error && <div className="mb-4 text-red-500">Error loading data: {error.message}</div>}

      {/* Statistics Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Total Queries</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.total}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Cache Hit Rate</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-green-600">
              {stats.total > 0 ? Math.round((stats.cacheHits / stats.total) * 100) : 0}%
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
            <CardTitle className="text-sm font-medium">Query Types</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.queryTypes}</div>
          </CardContent>
        </Card>
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
        {/* Cache Performance */}
        <Card>
          <CardHeader>
            <CardTitle>Cache Performance</CardTitle>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={300}>
              <PieChart>
                <Pie
                  data={getCachePerformanceData()}
                  cx="50%"
                  cy="50%"
                  labelLine={false}
                  label={({ name, percent }) => `${name} ${((percent ?? 0) * 100).toFixed(0)}%`}
                  outerRadius={80}
                  fill="#8884d8"
                  dataKey="value"
                >
                  {getCachePerformanceData().map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.color} />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
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
                <Line type="monotone" dataKey="avg" stroke="#3b82f6" strokeWidth={2} />
              </LineChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>
      </div>

      {/* Query Type Statistics */}
      <div className="mb-8">
        <h2 className="text-xl font-semibold mb-4">Query Type Statistics</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {queryTypeStats.map((stat) => (
            <Card key={stat.name}>
              <CardHeader>
                <CardTitle className="text-lg">{stat.name}</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-2">
                  <div className="flex justify-between">
                    <span className="text-sm text-gray-500">Executions</span>
                    <span className="font-medium">{stat.count}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-sm text-gray-500">Avg Response</span>
                    <span className="font-medium">{stat.avgResponseTime}ms</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-sm text-gray-500">Cache Hit Rate</span>
                    <span className="font-medium text-green-600">{stat.cacheHitRate}%</span>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>

      {/* Filters */}
      <div className="flex gap-4 mb-6">
        <div>
          <label className="block text-sm font-medium mb-1">Query Type</label>
          <select
            value={selectedQueryType}
            onChange={(e) => setSelectedQueryType(e.target.value)}
            className="border rounded px-3 py-2"
          >
            <option value="all">All Query Types</option>
            {queryTypes.map(type => (
              <option key={type} value={type}>{type}</option>
            ))}
          </select>
        </div>
      </div>

      {/* Query List */}
      <Card>
        <CardHeader>
          <CardTitle>Recent Queries</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {filteredQueries.slice(0, 30).map((query) => (
              <div
                key={query.id}
                className="border rounded p-4 hover:shadow-md transition-shadow"
              >
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center space-x-3">
                    <Badge className="bg-purple-500">{query.queryType}</Badge>
                    <Badge
                      className={query.cacheHit ? "bg-green-500" : "bg-gray-500"}
                    >
                      {query.cacheHit ? "Cache Hit" : "Cache Miss"}
                    </Badge>
                    <span className="text-sm text-gray-500">{query.responseTime}ms</span>
                    <span className="text-sm text-gray-500">{(query.dataSize / 1024).toFixed(1)}KB</span>
                  </div>
                  <span className="text-sm text-gray-500">
                    {new Date(query.timestamp).toLocaleString()}
                  </span>
                </div>
                {query.filters && Object.keys(query.filters).length > 0 && (
                  <details className="mt-2">
                    <summary className="cursor-pointer text-sm text-gray-600 hover:text-gray-800">
                      View Filters
                    </summary>
                    <pre className="mt-2 p-2 bg-gray-50 dark:bg-gray-800 rounded text-xs overflow-x-auto">
                      {JSON.stringify(query.filters, null, 2)}
                    </pre>
                  </details>
                )}
              </div>
            ))}
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
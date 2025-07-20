"use client"

import { gql, useQuery } from "@apollo/client"
import { ChevronDown, ChevronRight } from "lucide-react"
import { useEffect, useState } from "react"
import { Badge } from "@/components/ui/badge"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"

// GraphQL queries
const GET_ORDERS = gql`
  query GetOrders {
    orders {
      id
      userId
      status
      totalAmount
      createdAt
      updatedAt
      sagaId
      sagaStatus
      sagaCurrentStep
      items {
        productId
        productName
        quantity
        unitPrice
      }
    }
  }
`

const GET_PRODUCTS = gql`
  query GetProducts {
    products {
      id
      name
      description
      price
      stockQuantity
      active
      category {
        id
        name
      }
    }
  }
`

const GET_CATEGORIES = gql`
  query GetCategories {
    categories {
      id
      name
      description
      active
      products {
        id
        name
      }
    }
  }
`

interface Event {
  id: string
  aggregate_id: string
  aggregate_type: string
  event_type: string
  event_data: any
  event_version: number
  timestamp: string
  sequence_number: number
  metadata?: any
}

interface EventTypeStats {
  [type: string]: number
}

export default function EventsPage() {
  const [events, setEvents] = useState<Event[]>([])
  const [selectedType, setSelectedType] = useState<string>("all")
  const [expandedEvents, setExpandedEvents] = useState<Set<string>>(new Set())
  const [eventTypeStats, setEventTypeStats] = useState<EventTypeStats>({})

  // Query for orders data
  const { data: ordersData, loading: ordersLoading } = useQuery(GET_ORDERS, {
    pollInterval: 5000, // Poll every 5 seconds
  })

  // Query for products data
  const { data: productsData, loading: productsLoading } = useQuery(GET_PRODUCTS, {
    pollInterval: 5000,
  })

  // Query for categories data
  const { data: categoriesData, loading: categoriesLoading } = useQuery(GET_CATEGORIES, {
    pollInterval: 5000,
  })

  useEffect(() => {
    // Convert GraphQL data to event format
    const allEvents: Event[] = []
    let sequenceNumber = 1

    // Convert categories to events
    if (categoriesData?.categories) {
      categoriesData.categories.forEach((category: any) => {
        allEvents.push({
          id: `cat-evt-${category.id}`,
          aggregate_id: category.id,
          aggregate_type: "category",
          event_type: "category.created",
          event_data: {
            id: category.id,
            name: category.name,
            description: category.description,
            active: category.active,
          },
          event_version: 1,
          timestamp: new Date().toISOString(),
          sequence_number: sequenceNumber++,
          metadata: {
            source: "GraphQL Query",
          },
        })
      })
    }

    // Convert products to events
    if (productsData?.products) {
      productsData.products.forEach((product: any) => {
        allEvents.push({
          id: `prod-evt-${product.id}`,
          aggregate_id: product.id,
          aggregate_type: "product",
          event_type: "product.created",
          event_data: {
            id: product.id,
            name: product.name,
            description: product.description,
            price: product.price,
            stock_quantity: product.stockQuantity,
            category_id: product.category?.id,
            category_name: product.category?.name,
          },
          event_version: 1,
          timestamp: new Date().toISOString(),
          sequence_number: sequenceNumber++,
          metadata: {
            source: "GraphQL Query",
          },
        })
      })
    }

    // Convert orders to events
    if (ordersData?.orders) {
      ordersData.orders.forEach((order: any) => {
        // Order created event
        allEvents.push({
          id: `ord-evt-${order.id}-created`,
          aggregate_id: order.id,
          aggregate_type: "order",
          event_type: "order.created",
          event_data: {
            id: order.id,
            user_id: order.userId,
            items: order.items,
            total_amount: order.totalAmount,
          },
          event_version: 1,
          timestamp: order.createdAt,
          sequence_number: sequenceNumber++,
          metadata: {
            source: "GraphQL Query",
          },
        })

        // Order status events based on saga status
        if (order.sagaStatus && order.sagaStatus !== "started") {
          allEvents.push({
            id: `ord-evt-${order.id}-${order.sagaStatus}`,
            aggregate_id: order.id,
            aggregate_type: "order",
            event_type: `order.${order.sagaStatus}`,
            event_data: {
              id: order.id,
              status: order.status,
              saga_id: order.sagaId,
              saga_status: order.sagaStatus,
              current_step: order.sagaCurrentStep,
            },
            event_version: 2,
            timestamp: order.updatedAt,
            sequence_number: sequenceNumber++,
            metadata: {
              source: "GraphQL Query",
              saga_id: order.sagaId,
            },
          })
        }
      })
    }

    // Sort events by sequence number
    allEvents.sort((a, b) => b.sequence_number - a.sequence_number)
    setEvents(allEvents)

    // Calculate event type statistics
    const stats: EventTypeStats = {}
    allEvents.forEach((event) => {
      stats[event.event_type] = (stats[event.event_type] || 0) + 1
    })
    setEventTypeStats(stats)
  }, [ordersData, productsData, categoriesData])

  const toggleEventExpansion = (eventId: string) => {
    const newExpanded = new Set(expandedEvents)
    if (newExpanded.has(eventId)) {
      newExpanded.delete(eventId)
    } else {
      newExpanded.add(eventId)
    }
    setExpandedEvents(newExpanded)
  }

  const getEventColor = (eventType: string) => {
    if (eventType.includes("created")) return "bg-green-500"
    if (eventType.includes("updated")) return "bg-blue-500"
    if (eventType.includes("deleted")) return "bg-red-500"
    if (eventType.includes("completed")) return "bg-purple-500"
    if (eventType.includes("failed")) return "bg-orange-500"
    return "bg-gray-500"
  }

  const filteredEvents =
    selectedType === "all" ? events : events.filter((e) => e.event_type === selectedType)

  const aggregateTypes = new Set(events.map((e) => e.aggregate_type))
  const _totalDataSize = events.reduce((acc, e) => acc + JSON.stringify(e.event_data).length, 0)

  const isLoading = ordersLoading || productsLoading || categoriesLoading

  return (
    <div className="container mx-auto p-8">
      <h1 className="text-3xl font-bold mb-6">Event Store</h1>

      {isLoading && <div className="mb-4 text-gray-500">Loading data...</div>}

      {/* Statistics */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Total Events</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{events.length}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Event Types</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{Object.keys(eventTypeStats).length}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Aggregates</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{aggregateTypes.size}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Latest Sequence</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {events.length > 0 ? Math.max(...events.map((e) => e.sequence_number)) : 0}
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Event Type Filter */}
      <div className="mb-6">
        <label htmlFor="event-type-select" className="block text-sm font-medium mb-2">
          Filter by Event Type
        </label>
        <select
          id="event-type-select"
          value={selectedType}
          onChange={(e) => setSelectedType(e.target.value)}
          className="w-full md:w-64 border rounded px-3 py-2"
        >
          <option value="all">All Event Types</option>
          {Object.entries(eventTypeStats)
            .sort((a, b) => b[1] - a[1])
            .map(([type, count]) => (
              <option key={type} value={type}>
                {type} ({count})
              </option>
            ))}
        </select>
      </div>

      {/* Events List */}
      <Card>
        <CardHeader>
          <CardTitle>Events</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {filteredEvents.map((event) => (
              <div key={event.id} className="border rounded p-4 hover:shadow-md transition-shadow">
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <div className="flex items-center space-x-2 mb-2">
                      <Badge className={getEventColor(event.event_type)}>{event.event_type}</Badge>
                      <span className="text-sm text-gray-500">#{event.sequence_number}</span>
                      <span className="text-sm text-gray-500">v{event.event_version}</span>
                    </div>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-2 text-sm">
                      <div>
                        <span className="font-medium">Aggregate:</span>{" "}
                        <span className="font-mono">
                          {event.aggregate_type}/{event.aggregate_id.substring(0, 8)}...
                        </span>
                      </div>
                      <div>
                        <span className="font-medium">Time:</span>{" "}
                        {new Date(event.timestamp).toLocaleString()}
                      </div>
                    </div>
                  </div>
                  <button
                    type="button"
                    onClick={() => toggleEventExpansion(event.id)}
                    className="ml-4 p-1 hover:bg-gray-100 rounded"
                  >
                    {expandedEvents.has(event.id) ? (
                      <ChevronDown className="w-5 h-5" />
                    ) : (
                      <ChevronRight className="w-5 h-5" />
                    )}
                  </button>
                </div>

                {expandedEvents.has(event.id) && (
                  <div className="mt-4 space-y-2">
                    <div>
                      <h4 className="font-medium mb-1">Event Data:</h4>
                      <pre className="bg-gray-50 dark:bg-gray-800 p-3 rounded text-xs overflow-x-auto">
                        {JSON.stringify(event.event_data, null, 2)}
                      </pre>
                    </div>
                    {event.metadata && Object.keys(event.metadata).length > 0 && (
                      <div>
                        <h4 className="font-medium mb-1">Metadata:</h4>
                        <pre className="bg-gray-50 dark:bg-gray-800 p-3 rounded text-xs overflow-x-auto">
                          {JSON.stringify(event.metadata, null, 2)}
                        </pre>
                      </div>
                    )}
                  </div>
                )}
              </div>
            ))}
          </div>
        </CardContent>
      </Card>
    </div>
  )
}

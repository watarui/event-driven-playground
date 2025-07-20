import { gql } from "@apollo/client"
import { Context, Effect, Layer, Queue, Schedule, Stream } from "effect"
import { apolloClient } from "@/lib/apollo-client"

// Service definitions
export class MonitoringService extends Context.Tag("MonitoringService")<
  MonitoringService,
  {
    readonly fetchSagas: Effect.Effect<Array<Saga>, Error>
    readonly fetchEvents: Effect.Effect<Array<Event>, Error>
    readonly subscribeToEvents: Stream.Stream<Event, Error>
    readonly getMetrics: Effect.Effect<SystemMetrics, Error>
  }
>() {}

export class DatabaseService extends Context.Tag("DatabaseService")<
  DatabaseService,
  {
    readonly queryEventStore: (sql: string) => Effect.Effect<Array<any>, Error>
    readonly queryCommandDb: (sql: string) => Effect.Effect<Array<any>, Error>
    readonly queryQueryDb: (sql: string) => Effect.Effect<Array<any>, Error>
  }
>() {}

// Types
export interface Saga {
  id: string
  saga_id: string
  saga_type: string
  aggregate_id: string
  status: string
  current_step: string
  step_data: any
  error_reason?: string
  created_at: string
  updated_at: string
}

export interface Event {
  id: string
  aggregate_id: string
  aggregate_type: string
  event_type: string
  event_data: any
  metadata: any
  version: number
  global_sequence?: number
  inserted_at: string
}

export interface SystemMetrics {
  totalCommands: number
  totalQueries: number
  totalEvents: number
  avgResponseTime: number
  errorRate: number
}

// GraphQL Queries
const GET_ORDERS = gql`
  query GetOrders {
    orders {
      id
      customerId
      status
      totalAmount {
        amount
        currency
      }
      createdAt
      updatedAt
    }
  }
`

// Implementation
export const MonitoringServiceLive = Layer.succeed(
  MonitoringService,
  MonitoringService.of({
    fetchSagas: Effect.tryPromise({
      try: async () => {
        // In real implementation, this would query the database
        // For now, return mock data
        return [
          {
            id: "1",
            saga_id: "saga-123",
            saga_type: "OrderSaga",
            aggregate_id: "order-456",
            status: "completed",
            current_step: "ConfirmOrder",
            step_data: {},
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          },
        ] as Saga[]
      },
      catch: (error) => new Error(`Failed to fetch sagas: ${error}`),
    }),

    fetchEvents: Effect.tryPromise({
      try: async () => {
        // Mock implementation
        return [] as Event[]
      },
      catch: (error) => new Error(`Failed to fetch events: ${error}`),
    }),

    subscribeToEvents: Stream.async<Event>((emit) => {
      // In real implementation, this would connect to WebSocket
      const interval = setInterval(() => {
        emit.single({
          id: `evt-${Date.now()}`,
          aggregate_id: `agg-${Math.random()}`,
          aggregate_type: "Order",
          event_type: "OrderCreated",
          event_data: {},
          metadata: {},
          version: 1,
          inserted_at: new Date().toISOString(),
        })
      }, 5000)

      return Effect.sync(() => clearInterval(interval))
    }),

    getMetrics: Effect.succeed({
      totalCommands: 150,
      totalQueries: 500,
      totalEvents: 1200,
      avgResponseTime: 45,
      errorRate: 0.02,
    }),
  })
)

// Database Service Implementation
export const DatabaseServiceLive = Layer.succeed(
  DatabaseService,
  DatabaseService.of({
    queryEventStore: (sql: string) =>
      Effect.tryPromise({
        try: async () => {
          // Mock implementation
          console.log("Querying event store:", sql)
          return []
        },
        catch: (error) => new Error(`Database query failed: ${error}`),
      }),

    queryCommandDb: (sql: string) =>
      Effect.tryPromise({
        try: async () => {
          console.log("Querying command db:", sql)
          return []
        },
        catch: (error) => new Error(`Database query failed: ${error}`),
      }),

    queryQueryDb: (sql: string) =>
      Effect.tryPromise({
        try: async () => {
          console.log("Querying query db:", sql)
          return []
        },
        catch: (error) => new Error(`Database query failed: ${error}`),
      }),
  })
)

// Composed Layer
export const AppLayer = Layer.mergeAll(MonitoringServiceLive, DatabaseServiceLive)

// Helper functions for React components
export const createMonitoringProgram = () => {
  const program = Effect.gen(function* () {
    const monitoring = yield* MonitoringService

    // Fetch initial data
    const sagas = yield* monitoring.fetchSagas
    const events = yield* monitoring.fetchEvents
    const metrics = yield* monitoring.getMetrics

    return { sagas, events, metrics }
  })

  return program
}

// Event stream with retry logic
export const createEventStream = () => {
  return Effect.gen(function* () {
    const monitoring = yield* MonitoringService
    const queue = yield* Queue.unbounded<Event>()

    // Subscribe to events and pipe to queue
    yield* monitoring.subscribeToEvents
      .pipe(
        Stream.retry(Schedule.exponential("1 second")),
        Stream.runForEach((event) => Queue.offer(queue, event))
      )
      .pipe(Effect.fork)

    return queue
  })
}

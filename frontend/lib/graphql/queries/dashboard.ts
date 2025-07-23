import { gql } from "@apollo/client";

export const DASHBOARD_OVERVIEW = gql`
  query DashboardOverview {
    dashboardStats {
      totalEvents
      eventsPerMinute
      activeSagas
      totalCommands
      totalQueries
      systemHealth
      errorRate
      averageLatencyMs
    }
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
    recentEvents(limit: 10) {
      id
      aggregateId
      aggregateType
      eventType
      eventData
      eventVersion
      globalSequence
      metadata
      insertedAt
    }
    pubsubStats {
      topic
      messageCount
      messagesPerMinute
      lastMessageAt
    }
    systemTopology {
      serviceName
      nodeName
      status
      uptimeSeconds
      memoryUsageMb
      cpuUsagePercent
      messageQueueSize
      connections {
        targetService
        connectionType
        status
        latencyMs
      }
    }
  }
`;

export const EVENT_STREAM_SUBSCRIPTION = gql`
  subscription EventStream {
    eventStream {
      id
      aggregateId
      aggregateType
      eventType
      eventData
      eventVersion
      globalSequence
      metadata
      insertedAt
    }
  }
`;

export const DASHBOARD_STATS_SUBSCRIPTION = gql`
  subscription DashboardStatsStream {
    dashboardStatsStream {
      totalEvents
      eventsPerMinute
      activeSagas
      totalCommands
      totalQueries
      systemHealth
      errorRate
      averageLatencyMs
    }
  }
`;

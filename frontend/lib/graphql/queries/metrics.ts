import { gql } from "@apollo/client"

export const METRICS_OVERVIEW = gql`
  query MetricsOverview {
    metricsOverview {
      system {
        cpuUsage
        memoryUsage
        diskUsage
        processCount
        threadCount
        networkIo {
          bytesIn
          bytesOut
          packetsIn
          packetsOut
        }
      }
      application {
        httpRequestsTotal
        httpRequestDurationP50
        httpRequestDurationP95
        httpRequestDurationP99
        errorRate
        activeConnections
      }
      cqrs {
        commandsTotal
        commandsPerSecond
        commandErrorRate
        eventsTotal
        eventsPerSecond
        queriesTotal
        queriesPerSecond
      }
      saga {
        activeSagas
        completedSagas
        failedSagas
        compensatedSagas
        sagaDurationP50
        sagaDurationP95
      }
      timestamp
    }
  }
`

export const METRICS_STREAM_SUBSCRIPTION = gql`
  subscription MetricsStream {
    metricsStream {
      system {
        cpuUsage
        memoryUsage
        processCount
      }
      application {
        httpRequestsTotal
        errorRate
        activeConnections
      }
      cqrs {
        commandsPerSecond
        eventsPerSecond
      }
      saga {
        activeSagas
      }
      timestamp
    }
  }
`

export const METRIC_TIME_SERIES = gql`
  query MetricTimeSeries($metricNames: [String!]!, $duration: Int) {
    metricSeries(metricNames: $metricNames, duration: $duration) {
      metricName
      labels {
        name
        value
      }
      values {
        timestamp
        value
      }
    }
  }
`

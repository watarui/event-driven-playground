import { gql } from "@apollo/client";

export const LIST_PUBSUB_MESSAGES = gql`
  query ListPubSubMessages($topic: String, $limit: Int, $afterTimestamp: DateTime) {
    pubsubMessages(topic: $topic, limit: $limit, afterTimestamp: $afterTimestamp) {
      id
      topic
      messageType
      payload
      timestamp
      sourceService
    }
  }
`;

export const PUBSUB_STATS = gql`
  query PubSubStats {
    pubsubStats {
      topic
      messageCount
      messagesPerMinute
      lastMessageAt
    }
  }
`;

export const PUBSUB_MESSAGE_STREAM = gql`
  subscription PubSubMessageStream($topic: String) {
    pubsubStream(topic: $topic) {
      id
      topic
      messageType
      payload
      timestamp
      sourceService
    }
  }
`;

export const DASHBOARD_STATS = gql`
  query DashboardStats {
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
  }
`;

export const DASHBOARD_STATS_STREAM = gql`
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

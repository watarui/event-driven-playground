import { gql } from "@apollo/client";

export const LIST_SAGAS = gql`
  query ListSagas($status: String, $sagaType: String, $limit: Int, $offset: Int) {
    sagas(status: $status, sagaType: $sagaType, limit: $limit, offset: $offset) {
      id
      sagaType
      status
      state
      commandsDispatched {
        commandType
        commandData
        timestamp
      }
      eventsHandled
      createdAt
      updatedAt
      correlationId
    }
  }
`;

export const GET_SAGA = gql`
  query GetSaga($id: ID!) {
    saga(id: $id) {
      id
      sagaType
      status
      state
      commandsDispatched {
        commandType
        commandData
        timestamp
      }
      eventsHandled
      createdAt
      updatedAt
      correlationId
    }
  }
`;

export const SAGA_UPDATES_SUBSCRIPTION = gql`
  subscription SagaUpdates($sagaType: String) {
    sagaUpdates(sagaType: $sagaType) {
      id
      sagaType
      status
      state
      commandsDispatched {
        commandType
        commandData
        timestamp
      }
      eventsHandled
      createdAt
      updatedAt
      correlationId
    }
  }
`;

export const SYSTEM_STATISTICS = gql`
  query SystemStatistics {
    systemStatistics {
      sagas {
        active
        completed
        failed
        compensated
        total
      }
    }
  }
`;

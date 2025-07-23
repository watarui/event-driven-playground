import { gql } from "@apollo/client"

// Event Subscriptions
export const EVENT_CREATED_SUBSCRIPTION = gql`
  subscription OnEventCreated {
    eventCreated {
      id
      aggregateId
      aggregateType
      eventType
      eventData
      metadata
      version
      insertedAt
    }
  }
`

// Order Subscriptions
export const ORDER_UPDATED_SUBSCRIPTION = gql`
  subscription OnOrderUpdated($customerId: ID) {
    orderUpdated(customerId: $customerId) {
      id
      customerId
      status
      totalAmount {
        amount
        currency
      }
      items {
        productId
        quantity
        price {
          amount
          currency
        }
      }
      createdAt
      updatedAt
    }
  }
`

// Product Subscriptions
export const PRODUCT_UPDATED_SUBSCRIPTION = gql`
  subscription OnProductUpdated($categoryId: ID) {
    productUpdated(categoryId: $categoryId) {
      id
      name
      description
      price {
        amount
        currency
      }
      stock
      categoryId
      category {
        id
        name
      }
    }
  }
`

// Category Subscriptions
export const CATEGORY_UPDATED_SUBSCRIPTION = gql`
  subscription OnCategoryUpdated {
    categoryUpdated {
      id
      name
      description
    }
  }
`

// SAGA Subscriptions
export const SAGA_STATUS_SUBSCRIPTION = gql`
  subscription OnSagaStatusChanged {
    sagaStatusChanged {
      id
      sagaId
      sagaType
      aggregateId
      status
      currentStep
      stepData
      errorReason
      createdAt
      updatedAt
    }
  }
`

// System Events Subscription
export const SYSTEM_EVENT_SUBSCRIPTION = gql`
  subscription OnSystemEvent($eventType: String) {
    systemEvent(eventType: $eventType) {
      type
      payload
      timestamp
    }
  }
`

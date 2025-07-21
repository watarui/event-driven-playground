locals {
  # Event topics definition
  event_topics = toset([
    "all-events",
    "order-events",
    "product-events",
    "category-events",
    "saga-events"
  ])
  
  # Command topics definition
  command_topics = toset([
    "command-requests",
    "command-responses"
  ])
  
  # Query topics definition
  query_topics = toset([
    "query-requests",
    "query-responses"
  ])
  
  # Services that subscribe to topics
  subscribing_services = toset([
    "command-service",
    "query-service",
    "client-service"
  ])
  
  # Generate all event subscription combinations
  event_subscriptions = {
    for pair in setproduct(local.subscribing_services, local.event_topics) :
    "${pair[0]}-${pair[1]}" => {
      service = pair[0]
      topic   = pair[1]
    }
  }
  
  # Generate all command subscription combinations
  command_subscriptions = {
    for pair in setproduct(local.subscribing_services, local.command_topics) :
    "${pair[0]}-${pair[1]}" => {
      service = pair[0]
      topic   = pair[1]
    }
  }
  
  # Generate all query subscription combinations
  query_subscriptions = {
    for pair in setproduct(local.subscribing_services, local.query_topics) :
    "${pair[0]}-${pair[1]}" => {
      service = pair[0]
      topic   = pair[1]
    }
  }
}
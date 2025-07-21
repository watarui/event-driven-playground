# Event topics
resource "google_pubsub_topic" "event_topics" {
  for_each = local.event_topics
  
  project = var.project_id
  name = "${each.value}-${var.environment}"
  
  message_retention_duration = "604800s" # 7 days
}

# Command topics
resource "google_pubsub_topic" "command_topics" {
  for_each = local.command_topics
  
  project = var.project_id
  name = "${each.value}-${var.environment}"
  
  message_retention_duration = "86400s" # 1 day
}

# Query topics
resource "google_pubsub_topic" "query_topics" {
  for_each = local.query_topics
  
  project = var.project_id
  name = "${each.value}-${var.environment}"
  
  message_retention_duration = "86400s" # 1 day
}

# Dead letter topic
resource "google_pubsub_topic" "dead_letter" {
  project = var.project_id
  name = "dead-letter-${var.environment}"
  
  message_retention_duration = "2592000s" # 30 days
}

# Subscriptions for event topics
resource "google_pubsub_subscription" "event_subscriptions" {
  for_each = local.event_subscriptions
  
  project = var.project_id
  name  = "${each.value.service}-${each.value.topic}-sub-${var.environment}"
  topic = google_pubsub_topic.event_topics[each.value.topic].id
  
  ack_deadline_seconds = 30
  
  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }
  
  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = 5
  }
  
  enable_message_ordering = true
  
  expiration_policy {
    ttl = ""
  }
}

# Command service subscriptions
resource "google_pubsub_subscription" "command_subscriptions" {
  project = var.project_id
  name  = "command-service-requests-sub-${var.environment}"
  topic = google_pubsub_topic.command_topics["command-requests"].id
  
  ack_deadline_seconds = 30
  
  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "300s"
  }
  
  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = 5
  }
}

# Query service subscriptions
resource "google_pubsub_subscription" "query_subscriptions" {
  project = var.project_id
  name  = "query-service-requests-sub-${var.environment}"
  topic = google_pubsub_topic.query_topics["query-requests"].id
  
  ack_deadline_seconds = 30
  
  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "300s"
  }
  
  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = 5
  }
}
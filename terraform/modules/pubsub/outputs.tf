output "topics" {
  description = "Created Pub/Sub topics"
  value = merge(
    { for k, v in google_pubsub_topic.event_topics : k => v.id },
    { for k, v in google_pubsub_topic.command_topics : k => v.id },
    { for k, v in google_pubsub_topic.query_topics : k => v.id }
  )
}

output "subscriptions" {
  description = "Created Pub/Sub subscriptions"
  value = merge(
    { for k, v in google_pubsub_subscription.event_subscriptions : k => v.id },
    { "command-requests" = google_pubsub_subscription.command_subscriptions.id },
    { "query-requests" = google_pubsub_subscription.query_subscriptions.id }
  )
}

output "dead_letter_topic" {
  description = "Dead letter topic ID"
  value       = google_pubsub_topic.dead_letter.id
}
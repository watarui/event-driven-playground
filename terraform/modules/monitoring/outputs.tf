output "dashboard_url" {
  description = "URL to the monitoring dashboard"
  value       = "https://console.cloud.google.com/monitoring/dashboards/custom/${google_monitoring_dashboard.cqrs_dashboard.id}?project=${var.project_id}"
}

output "alert_policies" {
  description = "Created alert policies"
  value = {
    high_error_rate = google_monitoring_alert_policy.high_error_rate.name
    high_latency    = google_monitoring_alert_policy.high_latency.name
    pubsub_backlog  = google_monitoring_alert_policy.pubsub_backlog.name
  }
}
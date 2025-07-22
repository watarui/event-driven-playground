# Storage bucket for logs
resource "google_storage_bucket" "log_bucket" {
  name          = "${var.project_id}-cloud-run-logs"
  location      = var.region
  storage_class = "STANDARD"
  
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }
  
  versioning {
    enabled = false
  }
}

# Grant permissions to the log sink's service account
resource "google_storage_bucket_iam_member" "log_sink_writer" {
  bucket = google_storage_bucket.log_bucket.name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.cloud_run_logs.writer_identity
}

# Log sink for centralized logging
resource "google_logging_project_sink" "cloud_run_logs" {
  name        = "cloud-run-logs-${var.environment}"
  destination = "storage.googleapis.com/${google_storage_bucket.log_bucket.name}"
  
  filter = <<-EOT
    resource.type="cloud_run_revision"
    resource.labels.service_name="client-service" OR resource.labels.service_name="command-service" OR resource.labels.service_name="query-service"
  EOT
  
  unique_writer_identity = true
}

# Alerting policies
resource "google_monitoring_alert_policy" "high_error_rate" {
  display_name = "High Error Rate - ${var.environment}"
  combiner     = "OR"
  
  conditions {
    display_name = "Error rate > 1%"
    
    condition_threshold {
      filter = <<-EOT
        resource.type = "cloud_run_revision"
        (resource.labels.service_name = "client-service" OR resource.labels.service_name = "command-service" OR resource.labels.service_name = "query-service")
        metric.type = "run.googleapis.com/request_count"
        metric.labels.response_code_class != "2xx"
      EOT
      
      comparison      = "COMPARISON_GT"
      duration        = "60s"
      threshold_value = 0.01
      
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }
  
  notification_channels = var.notification_channels
  
  alert_strategy {
    auto_close = "1800s"
  }
}

resource "google_monitoring_alert_policy" "high_latency" {
  display_name = "High Latency - ${var.environment}"
  combiner     = "OR"
  
  conditions {
    display_name = "95th percentile latency > 1s"
    
    condition_threshold {
      filter = <<-EOT
        resource.type = "cloud_run_revision"
        (resource.labels.service_name = "client-service" OR resource.labels.service_name = "command-service" OR resource.labels.service_name = "query-service")
        metric.type = "run.googleapis.com/request_latencies"
      EOT
      
      comparison      = "COMPARISON_GT"
      duration        = "300s"
      threshold_value = 1000 # milliseconds
      
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_PERCENTILE_95"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.label.service_name"]
      }
    }
  }
  
  notification_channels = var.notification_channels
  
  alert_strategy {
    auto_close = "1800s"
  }
}

resource "google_monitoring_alert_policy" "pubsub_backlog" {
  display_name = "Pub/Sub Message Backlog - ${var.environment}"
  combiner     = "OR"
  
  conditions {
    display_name = "Unacknowledged messages > 1000"
    
    condition_threshold {
      filter = <<-EOT
        resource.type = "pubsub_subscription"
        metric.type = "pubsub.googleapis.com/subscription/num_undelivered_messages"
      EOT
      
      comparison      = "COMPARISON_GT"
      duration        = "300s"
      threshold_value = 1000
      
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MAX"
      }
    }
  }
  
  notification_channels = var.notification_channels
  
  alert_strategy {
    auto_close = "3600s"
  }
}

# Dashboard
resource "google_monitoring_dashboard" "cqrs_dashboard" {
  dashboard_json = jsonencode({
    displayName = "CQRS Application Dashboard - ${var.environment}"
    
    mosaicLayout = {
      columns = 12
      
      tiles = [
        # Request rate tile
        {
          width  = 6
          height = 4
          
          widget = {
            title = "Request Rate by Service"
            
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = <<-EOT
                      resource.type="cloud_run_revision"
                      (resource.labels.service_name="client-service" OR resource.labels.service_name="command-service" OR resource.labels.service_name="query-service")
                      metric.type="run.googleapis.com/request_count"
                    EOT
                    
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields = ["resource.label.service_name"]
                    }
                  }
                }
              }]
            }
          }
        },
        
        # Latency tile
        {
          xPos   = 6
          width  = 6
          height = 4
          
          widget = {
            title = "Request Latency (95th percentile)"
            
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = <<-EOT
                      resource.type="cloud_run_revision"
                      (resource.labels.service_name="client-service" OR resource.labels.service_name="command-service" OR resource.labels.service_name="query-service")
                      metric.type="run.googleapis.com/request_latencies"
                    EOT
                    
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_PERCENTILE_95"
                      crossSeriesReducer = "REDUCE_MEAN"
                      groupByFields      = ["resource.label.service_name"]
                    }
                  }
                }
              }]
            }
          }
        },
        
        # Error rate tile
        {
          yPos   = 4
          width  = 6
          height = 4
          
          widget = {
            title = "Error Rate"
            
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = <<-EOT
                      resource.type="cloud_run_revision"
                      (resource.labels.service_name="client-service" OR resource.labels.service_name="command-service" OR resource.labels.service_name="query-service")
                      metric.type="run.googleapis.com/request_count"
                      metric.labels.response_code_class!="2xx"
                    EOT
                    
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["resource.label.service_name", "metric.label.response_code_class"]
                    }
                  }
                }
              }]
            }
          }
        },
        
        # Pub/Sub tile
        {
          xPos   = 6
          yPos   = 4
          width  = 6
          height = 4
          
          widget = {
            title = "Pub/Sub Message Backlog"
            
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"pubsub_subscription\" metric.type=\"pubsub.googleapis.com/subscription/num_undelivered_messages\""
                    
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_MAX"
                      groupByFields    = ["resource.label.subscription_id"]
                    }
                  }
                }
              }]
            }
          }
        }
      ]
    }
  })
}
# 一時的な監視設定ファイル（監視リソースのみを適用するため）

# Provider configuration
terraform {
  required_version = ">= 1.5"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = "event-driven-playground-prod"
  region  = "asia-northeast1"
}

# Variables
variable "alert_email_address" {
  default = "wataruby@gmail.com"
}

variable "environment" {
  default = "prod"
}

# メール通知チャンネル
resource "google_monitoring_notification_channel" "email_temp" {
  display_name = "Email Notification Channel"
  type         = "email"
  
  labels = {
    email_address = var.alert_email_address
  }
  
  enabled = true
}

# データベース接続エラーアラート
resource "google_monitoring_alert_policy" "database_connection_errors_temp" {
  display_name = "Database Connection Errors - ${var.environment}"
  combiner     = "OR"
  
  conditions {
    display_name = "Database connection errors detected"
    
    condition_matched_log {
      filter = <<-EOT
        resource.type="cloud_run_revision"
        resource.labels.service_name=~"^(client-service|command-service|query-service)$"
        textPayload=~"(connection.*failed|FATAL.*password|database.*does not exist)"
      EOT
      
      label_extractors = {
        "service" = "EXTRACT(resource.labels.service_name)"
      }
    }
  }
  
  notification_channels = [google_monitoring_notification_channel.email_temp.name]
  
  alert_strategy {
    notification_rate_limit {
      period = "300s"
    }
    auto_close = "1800s"
  }
  
  documentation {
    content = <<-EOT
      Database connection error detected.
      
      Check:
      1. Database is accessible
      2. Credentials in Secret Manager are correct
      3. Network connectivity from Cloud Run to database
    EOT
  }
}

# メモリ使用率アラート
resource "google_monitoring_alert_policy" "high_memory_usage_temp" {
  display_name = "High Memory Usage - ${var.environment}"
  combiner     = "OR"
  
  conditions {
    display_name = "Memory usage > 80%"
    
    condition_threshold {
      filter = <<-EOT
        resource.type = "cloud_run_revision"
        resource.labels.service_name = one_of("client-service", "command-service", "query-service")
        metric.type = "run.googleapis.com/container/memory/utilizations"
      EOT
      
      comparison      = "COMPARISON_GT"
      duration        = "300s"
      threshold_value = 0.8
      
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_PERCENTILE_95"
      }
    }
  }
  
  notification_channels = [google_monitoring_notification_channel.email_temp.name]
  
  alert_strategy {
    auto_close = "1800s"
  }
}

# Dashboard
resource "google_monitoring_dashboard" "cqrs_dashboard_temp" {
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
                      resource.labels.service_name=one_of("client-service", "command-service", "query-service")
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
                      resource.labels.service_name=one_of("client-service", "command-service", "query-service")
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
        }
      ]
    }
  })
}
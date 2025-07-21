# 監視とアラートの設定

# メール通知チャンネル
resource "google_monitoring_notification_channel" "email" {
  count = var.enable_monitoring ? 1 : 0
  
  display_name = "Email Notification Channel"
  type         = "email"
  
  labels = {
    email_address = var.alert_email_address
  }
  
  enabled = true
}


# 追加のカスタムアラート

# データベース接続エラーアラート
resource "google_monitoring_alert_policy" "database_connection_errors" {
  count = var.enable_monitoring ? 1 : 0
  
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
  
  notification_channels = [google_monitoring_notification_channel.email[0].name]
  
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
resource "google_monitoring_alert_policy" "high_memory_usage" {
  count = var.enable_monitoring ? 1 : 0
  
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
        per_series_aligner = "ALIGN_PERCENTILE_99"
      }
    }
  }
  
  notification_channels = [google_monitoring_notification_channel.email[0].name]
  
  alert_strategy {
    auto_close = "1800s"
  }
}
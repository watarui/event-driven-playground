locals {
  image_base = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_registry}"
}

# Cloud Run services
resource "google_cloud_run_v2_service" "services" {
  for_each = var.services
  
  name     = each.key
  location = var.region
  
  template {
    service_account = var.service_account
    
    scaling {
      min_instance_count = each.value.min_scale
      max_instance_count = each.value.max_scale
    }
    
    containers {
      image = "${local.image_base}/${each.key}:latest"
      
      # ports ブロックを削除 - Cloud Run が自動的に PORT 環境変数を設定する
      # ports {
      #   container_port = each.value.port
      # }
      
      resources {
        limits = {
          cpu    = each.value.cpu
          memory = each.value.memory
        }
        
        cpu_idle = true
        startup_cpu_boost = true
      }
      
      # Environment variables
      dynamic "env" {
        for_each = var.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }
      
      # Service-specific environment variables
      env {
        name  = "SERVICE_NAME"
        value = each.key
      }
      
      # PORT は Cloud Run が自動的に設定するため、手動で設定しない
      # env {
      #   name  = "PORT"
      #   value = tostring(each.value.port)
      # }
      
      # Secrets from Secret Manager
      dynamic "env" {
        for_each = var.secrets
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value
              version = "latest"
            }
          }
        }
      }
      
      # Health check
      liveness_probe {
        initial_delay_seconds = 10
        timeout_seconds       = 3
        period_seconds        = 10
        failure_threshold     = 3
        
        http_get {
          path = "/health"
          # Cloud Run が設定する PORT 環境変数を使用
        }
      }
      
      startup_probe {
        initial_delay_seconds = 0
        timeout_seconds       = 3
        period_seconds        = 10
        failure_threshold     = 10
        
        tcp_socket {
          # Cloud Run が設定する PORT 環境変数を使用
        }
      }
    }
    
    # VPC connector for internal communication
    # VPC connector を使用する場合は、先に VPC コネクタを作成する必要があります
    # vpc_access {
    #   egress = "PRIVATE_RANGES_ONLY"
    # }
  }
  
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
  
  deletion_protection = false
  
  # Gradual rollout
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
    ]
  }
}

# IAM policy for public access
# client-service: 全体を公開（GraphQL エンドポイント）
# その他のサービス: ヘルスチェックのみ公開したいが、Cloud Run は URL パスベースの認証をサポートしていないため、
# 現在は内部アクセスのみ。将来的に API Gateway や Load Balancer を使用して細かい制御を実装予定。
resource "google_cloud_run_service_iam_member" "public_access" {
  for_each = { for k, v in var.services : k => v if k == "client-service" }
  
  service  = google_cloud_run_v2_service.services[each.key].name
  location = google_cloud_run_v2_service.services[each.key].location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ヘルスチェック用の公開アクセス（すべてのサービス）
# 注意: これによりサービス全体が公開されるため、各サービスで適切な認証実装が必要
resource "google_cloud_run_service_iam_member" "health_check_access" {
  for_each = var.services
  
  service  = google_cloud_run_v2_service.services[each.key].name
  location = google_cloud_run_v2_service.services[each.key].location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Service URLs for internal communication
resource "google_secret_manager_secret" "service_urls" {
  for_each = google_cloud_run_v2_service.services
  
  secret_id = "${each.key}-url-${var.environment}"
  
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "service_urls_version" {
  for_each = google_secret_manager_secret.service_urls
  
  secret      = each.value.id
  secret_data = google_cloud_run_v2_service.services[each.key].uri
}
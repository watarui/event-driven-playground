# Cloud Run Jobs

# Database migration job for production environment
resource "google_cloud_run_v2_job" "database_migrate" {
  name     = "database-migrate"
  location = var.region
  project  = var.project_id
  
  deletion_protection = false
  
  template {
    template {
      service_account = var.service_account
      
      containers {
        image = "${local.image_base}/migrate:latest"
        
        resources {
          limits = {
            cpu    = "2"
            memory = "2Gi"
          }
          # リクエストを追加してリソースを保証
          requests = {
            cpu    = "1"
            memory = "1Gi"
          }
        }
        
        # Environment variables
        env {
          name  = "MIX_ENV"
          value = "prod"
        }
        
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
        
        # Additional environment variables for debugging
        dynamic "env" {
          for_each = var.env_vars
          content {
            name  = env.key
            value = env.value
          }
        }
      }
      
      timeout     = "900s"  # 15 minutes (マイグレーションに余裕を持たせる)
      max_retries = 0      # リトライは無効（マイグレーションの重複実行を避ける）
    }
    
    parallelism = 1
  }
  
  lifecycle {
    ignore_changes = [
      template[0].template[0].containers[0].image,
    ]
  }
}

# Individual migration jobs (for backward compatibility)
resource "google_cloud_run_v2_job" "migrate_shared" {
  name     = "migrate-shared-${var.environment}"
  location = var.region
  deletion_protection = false
  
  template {
    template {
      service_account = var.service_account
      
      containers {
        image = "${local.image_base}/client-service:latest"
        
        command = ["/app/bin/client_service"]
        args    = ["eval", "Shared.Release.migrate()"]
        
        resources {
          limits = {
            cpu    = "1"
            memory = "1Gi"
          }
        }
        
        # Environment variables
        dynamic "env" {
          for_each = var.env_vars
          content {
            name  = env.key
            value = env.value
          }
        }
        
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
      }
      
      timeout = "600s"
      max_retries = 1
    }
  }
  
  lifecycle {
    ignore_changes = [
      template[0].template[0].containers[0].image,
    ]
  }
}

resource "google_cloud_run_v2_job" "migrate_command" {
  name     = "migrate-command-${var.environment}"
  location = var.region
  deletion_protection = false
  
  template {
    template {
      service_account = var.service_account
      
      containers {
        image = "${local.image_base}/command-service:latest"
        
        command = ["/app/bin/command_service"]
        args    = ["eval", "CommandService.Release.migrate()"]
        
        resources {
          limits = {
            cpu    = "1"
            memory = "1Gi"
          }
        }
        
        # Environment variables
        dynamic "env" {
          for_each = var.env_vars
          content {
            name  = env.key
            value = env.value
          }
        }
        
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
      }
      
      timeout = "600s"
      max_retries = 1
    }
  }
  
  lifecycle {
    ignore_changes = [
      template[0].template[0].containers[0].image,
    ]
  }
}

resource "google_cloud_run_v2_job" "migrate_query" {
  name     = "migrate-query-${var.environment}"
  location = var.region
  deletion_protection = false
  
  template {
    template {
      service_account = var.service_account
      
      containers {
        image = "${local.image_base}/query-service:latest"
        
        command = ["/app/bin/query_service"]
        args    = ["eval", "QueryService.Release.migrate()"]
        
        resources {
          limits = {
            cpu    = "1"
            memory = "1Gi"
          }
        }
        
        # Environment variables
        dynamic "env" {
          for_each = var.env_vars
          content {
            name  = env.key
            value = env.value
          }
        }
        
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
      }
      
      timeout = "600s"
      max_retries = 1
    }
  }
  
  lifecycle {
    ignore_changes = [
      template[0].template[0].containers[0].image,
    ]
  }
}
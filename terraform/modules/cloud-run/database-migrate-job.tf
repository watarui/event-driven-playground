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
        }
        
        # Environment variables
        env {
          name  = "MIX_ENV"
          value = "prod"
        }
        
        # Database URL from Secret Manager
        env {
          name = "DATABASE_URL"
          value_source {
            secret_key_ref {
              secret  = var.secrets["supabase_url"]
              version = "latest"
            }
          }
        }
        
        # For production single DB setup, all services use the same URL
        env {
          name = "EVENT_STORE_DATABASE_URL"
          value_source {
            secret_key_ref {
              secret  = var.secrets["supabase_url"]
              version = "latest"
            }
          }
        }
        
        env {
          name = "COMMAND_SERVICE_DATABASE_URL"
          value_source {
            secret_key_ref {
              secret  = var.secrets["supabase_url"]
              version = "latest"
            }
          }
        }
        
        env {
          name = "QUERY_SERVICE_DATABASE_URL"
          value_source {
            secret_key_ref {
              secret  = var.secrets["supabase_url"]
              version = "latest"
            }
          }
        }
        
        env {
          name = "SECRET_KEY_BASE"
          value_source {
            secret_key_ref {
              secret  = var.secrets["secret_key_base"]
              version = "latest"
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
      
      timeout     = "600s"  # 10 minutes
      max_retries = 1
    }
    
    parallelism = 1
  }
  
  lifecycle {
    ignore_changes = [
      template[0].template[0].containers[0].image,
    ]
  }
  
  # Project service dependency is handled at the root module level
}

# Output the job name for reference
output "database_migrate_job_name" {
  value       = google_cloud_run_v2_job.database_migrate.name
  description = "The name of the database migration job"
}

# Output the job URI for monitoring
output "database_migrate_job_uri" {
  value       = google_cloud_run_v2_job.database_migrate.uri
  description = "The URI of the database migration job"
}
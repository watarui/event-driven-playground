# Migration job for Shared (EventStore) repo
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
        args    = ["eval", "Ecto.Migrator.with_repo(Shared.Infrastructure.EventStore.Repo, &Ecto.Migrator.run(&1, :up, all: true))"]
        
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

# Migration job for Command Service repo
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
        args    = ["eval", "Ecto.Migrator.with_repo(CommandService.Repo, &Ecto.Migrator.run(&1, :up, all: true))"]
        
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

# Migration job for Query Service repo
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
        args    = ["eval", "Shared.Release.migrate_query()"]
        
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
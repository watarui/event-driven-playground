locals {
  # Environment specific configuration
  environment = "prod"
  
  # Service configurations
  services = {
    client-service = {
      cpu       = "1"
      memory    = "512Mi"
      min_scale = 1
      max_scale = 100
      port      = 8080
    }
    command-service = {
      cpu       = "1"
      memory    = "512Mi"
      min_scale = 1
      max_scale = 50
      port      = 8081
    }
    query-service = {
      cpu       = "1"
      memory    = "512Mi"
      min_scale = 1
      max_scale = 50
      port      = 8082
    }
  }
  
  # Common environment variables
  common_env_vars = {
    MIX_ENV              = "prod"
    GOOGLE_CLOUD_PROJECT = var.project_id
    PUBSUB_EMULATOR_HOST = ""
    FIREBASE_PROJECT_ID  = var.firebase_config.project_id
    FIREBASE_AUTH_DOMAIN = var.firebase_config.auth_domain
    # Database connection pool settings for Cloud Run Job
    POOL_SIZE           = "2"  # Increased to 2 for migration operations
    DB_QUEUE_TARGET     = "50"
    DB_QUEUE_INTERVAL   = "100"
    DB_TIMEOUT          = "30000"
    DB_CONNECT_TIMEOUT  = "30000"
  }
}
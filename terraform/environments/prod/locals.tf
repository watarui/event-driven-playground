locals {
  # Environment specific configuration
  environment = "prod"
  
  # Service configurations
  services = {
    client-service = {
      cpu       = "1"
      memory    = "512Mi"
      min_scale = 0  # コスト削減のため0に設定（デモアプリ）
      max_scale = 100
    }
    command-service = {
      cpu       = "1"
      memory    = "512Mi"
      min_scale = 0  # コスト削減のため0に設定（デモアプリ）
      max_scale = 50
    }
    query-service = {
      cpu       = "1"
      memory    = "512Mi"
      min_scale = 0  # コスト削減のため0に設定（デモアプリ）
      max_scale = 50
    }
  }
  
  # Common environment variables
  common_env_vars = {
    MIX_ENV              = "prod"
    GOOGLE_CLOUD_PROJECT = var.project_id
    PUBSUB_EMULATOR_HOST = ""
    FIREBASE_PROJECT_ID  = var.firebase_config.project_id
    FIREBASE_AUTH_DOMAIN = var.firebase_config.auth_domain
    # Database adapter
    DATABASE_ADAPTER    = "firestore"
    # Firestore project IDs（本番では単一プロジェクト）
    FIRESTORE_PROJECT_ID = var.project_id
  }
}
# Secret Manager resources

locals {
  # シークレット名と値のマッピング（明確な名前を使用）
  secrets = {
    database_url         = var.supabase_url
    supabase_service_key = var.supabase_service_key
    firebase_api_key     = var.firebase_api_key
    secret_key_base      = var.secret_key_base
  }
  
  # シークレット ID のマッピング（ハイフンを使用）
  secret_ids = {
    database_url         = "database-url"
    supabase_service_key = "supabase-service-key"
    firebase_api_key     = "firebase-api-key"
    secret_key_base      = "secret-key-base"
  }
}

# Create secrets
resource "google_secret_manager_secret" "secrets" {
  for_each = local.secrets
  
  project   = var.project_id
  secret_id = local.secret_ids[each.key]
  
  replication {
    auto {}
  }
}

# Create secret versions
resource "google_secret_manager_secret_version" "secret_versions" {
  for_each = local.secrets
  
  secret      = google_secret_manager_secret.secrets[each.key].id
  secret_data = each.value
}
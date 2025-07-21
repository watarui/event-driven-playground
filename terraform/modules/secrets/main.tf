# Secret Manager resources

locals {
  # Define secrets and their values
  secrets = {
    supabase_url         = var.supabase_url
    supabase_service_key = var.supabase_service_key
    firebase_api_key     = var.firebase_api_key
    secret_key_base      = var.secret_key_base
  }
}

# Create secrets
resource "google_secret_manager_secret" "secrets" {
  for_each = local.secrets
  
  project   = var.project_id
  secret_id = replace(each.key, "_", "-")
  
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
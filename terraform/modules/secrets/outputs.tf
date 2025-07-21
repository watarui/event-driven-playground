output "secret_ids" {
  description = "Map of secret names to their IDs"
  value = {
    for k, v in google_secret_manager_secret.secrets : k => v.id
  }
}

output "secret_names" {
  description = "Map of secret names to their actual secret names in GCP"
  value = {
    for k, v in google_secret_manager_secret.secrets : k => v.secret_id
  }
}

output "DATABASE_URL" {
  description = "Database URL secret ID for Cloud Run"
  value       = google_secret_manager_secret.secrets["supabase_url"].id
}

output "SUPABASE_SERVICE_KEY" {
  description = "Supabase service key secret ID for Cloud Run"
  value       = google_secret_manager_secret.secrets["supabase_service_key"].id
}

output "FIREBASE_API_KEY" {
  description = "Firebase API key secret ID for Cloud Run"
  value       = google_secret_manager_secret.secrets["firebase_api_key"].id
}

output "SECRET_KEY_BASE" {
  description = "Secret key base secret ID for Cloud Run"
  value       = google_secret_manager_secret.secrets["secret_key_base"].id
}
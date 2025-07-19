output "web_app_id" {
  description = "Firebase Web App ID"
  value       = google_firebase_web_app.default.app_id
}

output "web_app_config" {
  description = "Firebase Web App configuration"
  value = {
    api_key    = var.firebase_config.api_key
    auth_domain = "${var.project_id}.firebaseapp.com"
    project_id  = var.project_id
    app_id      = google_firebase_web_app.default.app_id
  }
  sensitive = true
}
# Firebase project configuration
resource "google_firebase_project" "default" {
  provider = google-beta
  project  = var.project_id
}

# Enable Firebase Authentication
resource "google_identity_platform_config" "default" {
  provider = google-beta
  project  = var.project_id
  
  sign_in {
    allow_duplicate_emails = false
    
    email {
      enabled           = true
      password_required = true
    }
  }
  
  authorized_domains = [
    "${var.project_id}.firebaseapp.com",
    "${var.project_id}.web.app"
  ]
  
  depends_on = [google_firebase_project.default]
}

# Google Sign-In provider
resource "google_identity_platform_default_supported_idp_config" "google" {
  provider = google-beta
  project  = var.project_id
  
  enabled = true
  idp_id  = "google.com"
  
  client_id     = var.google_oauth_client_id
  client_secret = var.google_oauth_client_secret
  
  depends_on = [google_identity_platform_config.default]
}

# Firebase Web App
resource "google_firebase_web_app" "default" {
  provider     = google-beta
  project      = var.project_id
  display_name = "CQRS Demo App"
  
  depends_on = [google_firebase_project.default]
}
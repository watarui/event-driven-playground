# Provider configuration
provider "google" {
  project                     = var.project_id
  region                      = var.region
  user_project_override       = true
  billing_project             = var.project_id
}

provider "google-beta" {
  project                     = var.project_id
  region                      = var.region
  user_project_override       = true
  billing_project             = var.project_id
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "run.googleapis.com",
    "pubsub.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "secretmanager.googleapis.com",
    "firebase.googleapis.com",
    "identitytoolkit.googleapis.com"
  ])
  
  project = var.project_id
  service = each.value
  disable_on_destroy = false
}

# Artifact Registry for Docker images
resource "google_artifact_registry_repository" "event_driven_playground" {
  project       = var.project_id
  location      = var.region
  repository_id = "event-driven-playground"
  description   = "Docker repository for event-driven microservices"
  format        = "DOCKER"
  
  depends_on = [google_project_service.required_apis]
}

# Service Account for Cloud Run services
resource "google_service_account" "cloud_run_sa" {
  project      = var.project_id
  account_id   = "event-driven-playground-runner"
  display_name = "Event Driven Playground Cloud Run Service Account"
}

# IAM roles for Service Account
resource "google_project_iam_member" "cloud_run_roles" {
  for_each = toset([
    "roles/pubsub.publisher",
    "roles/pubsub.subscriber",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/cloudtrace.agent",
    "roles/secretmanager.secretAccessor"
  ])
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Secret Manager for sensitive data
resource "google_secret_manager_secret" "app_secrets" {
  for_each = {
    supabase_url         = var.supabase_url
    supabase_service_key = var.supabase_service_key
    firebase_api_key     = var.firebase_config.api_key
    secret_key_base      = var.secret_key_base
  }
  
  project   = var.project_id
  secret_id = replace(each.key, "_", "-")
  
  replication {
    auto {}
  }
  
  depends_on = [google_project_service.required_apis]
}

resource "google_secret_manager_secret_version" "app_secrets_version" {
  for_each = google_secret_manager_secret.app_secrets
  
  secret      = each.value.id
  secret_data = each.key == "supabase_url" ? var.supabase_url : each.key == "supabase_service_key" ? var.supabase_service_key : each.key == "firebase_api_key" ? var.firebase_config.api_key : var.secret_key_base
}

# Cloud Pub/Sub module
module "pubsub" {
  source = "../../modules/pubsub"
  
  project_id  = var.project_id
  environment = var.environment
  
  depends_on = [google_project_service.required_apis]
}

# Cloud Run services
module "cloud_run" {
  source = "../../modules/cloud-run"
  
  project_id           = var.project_id
  region              = var.region
  environment         = var.environment
  services            = var.services
  service_account     = google_service_account.cloud_run_sa.email
  artifact_registry   = google_artifact_registry_repository.event_driven_playground.repository_id
  
  env_vars = {
    MIX_ENV              = "prod"
    GOOGLE_CLOUD_PROJECT = var.project_id
    PUBSUB_EMULATOR_HOST = ""
    FIREBASE_PROJECT_ID  = var.firebase_config.project_id
    FIREBASE_AUTH_DOMAIN = var.firebase_config.auth_domain
  }
  
  secrets = {
    DATABASE_URL         = google_secret_manager_secret.app_secrets["supabase_url"].id
    SUPABASE_SERVICE_KEY = google_secret_manager_secret.app_secrets["supabase_service_key"].id
    FIREBASE_API_KEY     = google_secret_manager_secret.app_secrets["firebase_api_key"].id
    SECRET_KEY_BASE      = google_secret_manager_secret.app_secrets["secret_key_base"].id
  }
  
  depends_on = [
    google_project_service.required_apis,
    google_secret_manager_secret_version.app_secrets_version,
    module.pubsub
  ]
}

# Firebase module
module "firebase" {
  source = "../../modules/firebase"
  
  project_id = var.project_id
  firebase_config = var.firebase_config
  google_oauth_client_id = var.google_oauth_client_id
  google_oauth_client_secret = var.google_oauth_client_secret
  
  depends_on = [google_project_service.required_apis]
}

# Monitoring module
module "monitoring" {
  source = "../../modules/monitoring"
  
  count = var.enable_monitoring ? 1 : 0
  
  project_id   = var.project_id
  environment  = var.environment
  services     = keys(var.services)
  
  depends_on = [module.cloud_run]
}
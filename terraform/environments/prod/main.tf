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

# Secret Manager module
module "secrets" {
  source = "../../modules/secrets"
  
  project_id           = var.project_id
  supabase_url         = var.supabase_url
  supabase_service_key = var.supabase_service_key
  firebase_api_key     = var.firebase_config.api_key
  secret_key_base      = var.secret_key_base
  
  depends_on = [google_project_service.required_apis]
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
  services            = local.services
  service_account     = google_service_account.cloud_run_sa.email
  artifact_registry   = google_artifact_registry_repository.event_driven_playground.repository_id
  
  env_vars = local.common_env_vars
  
  secrets = module.secrets.secret_ids
  
  depends_on = [
    google_project_service.required_apis,
    module.secrets,
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
  
  notification_channels = var.enable_monitoring ? [google_monitoring_notification_channel.email[0].name] : []
  
  depends_on = [module.cloud_run]
}
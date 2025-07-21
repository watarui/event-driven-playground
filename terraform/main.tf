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
    "identitytoolkit.googleapis.com",
    "firestore.googleapis.com"
  ])
  
  service = each.value
  disable_on_destroy = false
}

# Artifact Registry for Docker images
resource "google_artifact_registry_repository" "event_driven_playground" {
  location      = var.region
  repository_id = "event-driven-playground"
  description   = "Docker repository for event-driven microservices"
  format        = "DOCKER"
  
  depends_on = [google_project_service.required_apis]
}

# Service Account for Cloud Run services
resource "google_service_account" "cloud_run_sa" {
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
    "roles/secretmanager.secretAccessor",
    "roles/datastore.user"
  ])
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Secret Manager for sensitive data
resource "google_secret_manager_secret" "app_secrets" {
  for_each = {
    firebase_api_key = var.firebase_config.api_key
  }
  
  secret_id = replace(each.key, "_", "-")
  
  replication {
    auto {}
  }
  
  depends_on = [google_project_service.required_apis]
}

resource "google_secret_manager_secret_version" "app_secrets_version" {
  for_each = google_secret_manager_secret.app_secrets
  
  secret      = each.value.id
  secret_data = var.firebase_config.api_key
}

# Cloud Pub/Sub module
module "pubsub" {
  source = "./modules/pubsub"
  
  project_id  = var.project_id
  environment = var.environment
  
  depends_on = [google_project_service.required_apis]
}

# Cloud Run services - Docker イメージをビルド後にコメントを外してください
# module "cloud_run" {
#   source = "./modules/cloud-run"
#   
#   project_id           = var.project_id
#   region              = var.region
#   environment         = var.environment
#   services            = var.services
#   service_account     = google_service_account.cloud_run_sa.email
#   artifact_registry   = google_artifact_registry_repository.event_driven_playground.id
#   
#   env_vars = {
#     MIX_ENV              = "prod"
#     GOOGLE_CLOUD_PROJECT = var.project_id
#     PUBSUB_EMULATOR_HOST = ""
#     FIREBASE_PROJECT_ID  = var.firebase_config.project_id
#     FIREBASE_AUTH_DOMAIN = var.firebase_config.auth_domain
#     DATABASE_ADAPTER     = "firestore"
#     FIRESTORE_PROJECT_ID = var.project_id
#   }
#   
#   secrets = {
#     FIREBASE_API_KEY = google_secret_manager_secret.app_secrets["firebase_api_key"].id
#   }
#   
#   depends_on = [
#     google_project_service.required_apis,
#     google_secret_manager_secret_version.app_secrets_version,
#     module.pubsub
#   ]
# }

# Firebase module
module "firebase" {
  source = "./modules/firebase"
  
  project_id = var.project_id
  firebase_config = var.firebase_config
  google_oauth_client_id = var.google_oauth_client_id
  google_oauth_client_secret = var.google_oauth_client_secret
  
  depends_on = [google_project_service.required_apis]
}

# Monitoring module - Cloud Run モジュールと一緒にコメントを外してください
# module "monitoring" {
#   source = "./modules/monitoring"
#   
#   count = var.enable_monitoring ? 1 : 0
#   
#   project_id   = var.project_id
#   environment  = var.environment
#   services     = keys(var.services)
#   
#   depends_on = [module.cloud_run]
# }
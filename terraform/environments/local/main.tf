# ローカル開発環境用の Terraform 構成
# Firebase Authentication (Google OAuth) のみを設定

terraform {
  required_version = ">= 1.9.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
  }
}

# Provider 設定
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

# 必要最小限の API を有効化
resource "google_project_service" "firebase_apis" {
  for_each = toset([
    "firebase.googleapis.com",
    "identitytoolkit.googleapis.com"
  ])
  
  service = each.value
  disable_on_destroy = false
}

# Firebase プロジェクト
resource "google_firebase_project" "default" {
  provider = google-beta
  project  = var.project_id
  
  depends_on = [google_project_service.firebase_apis]
}

# Firebase Authentication の設定
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
    "${var.project_id}.web.app",
    "localhost"  # ローカル開発用
  ]
  
  depends_on = [google_firebase_project.default]
}

# Google OAuth の設定
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
  display_name = "CQRS Demo App (Local)"
  
  depends_on = [google_firebase_project.default]
}
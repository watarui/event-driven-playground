variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "region" {
  description = "Default region for resources"
  type        = string
  default     = "asia-northeast1"
}

variable "firebase_config" {
  description = "Firebase configuration"
  type = object({
    api_key     = string
    auth_domain = string
    project_id  = string
  })
  sensitive = true
}

variable "google_oauth_client_id" {
  description = "Google OAuth Client ID for Firebase Authentication"
  type        = string
  sensitive   = true
}

variable "google_oauth_client_secret" {
  description = "Google OAuth Client Secret for Firebase Authentication"
  type        = string
  sensitive   = true
}
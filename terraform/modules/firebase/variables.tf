variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "firebase_config" {
  description = "Firebase configuration"
  type = object({
    api_key     = string
    auth_domain = string
    project_id  = string
  })
}

variable "google_oauth_client_id" {
  description = "Google OAuth 2.0 Client ID"
  type        = string
  default     = ""
}

variable "google_oauth_client_secret" {
  description = "Google OAuth 2.0 Client Secret"
  type        = string
  sensitive   = true
  default     = ""
}
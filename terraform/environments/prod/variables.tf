variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "region" {
  description = "Default region for resources"
  type        = string
  default     = "asia-northeast1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "services" {
  description = "Map of services configuration"
  type = map(object({
    memory     = string
    cpu        = string
    min_scale  = number
    max_scale  = number
    port       = number
  }))
  default = {
    command-service = {
      memory    = "512Mi"
      cpu       = "1"
      min_scale = 0
      max_scale = 10
      port      = 8080
    }
    query-service = {
      memory    = "512Mi"
      cpu       = "1"
      min_scale = 0
      max_scale = 10
      port      = 8080
    }
    client-service = {
      memory    = "1Gi"
      cpu       = "2"
      min_scale = 1
      max_scale = 20
      port      = 4000
    }
  }
}

variable "supabase_url" {
  description = "Supabase project URL"
  type        = string
  sensitive   = true
}

variable "supabase_service_key" {
  description = "Supabase service role key"
  type        = string
  sensitive   = true
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

variable "enable_monitoring" {
  description = "Enable Cloud Monitoring and Logging"
  type        = bool
  default     = true
}

variable "domain" {
  description = "Custom domain for the application"
  type        = string
  default     = ""
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

variable "secret_key_base" {
  description = "Phoenix secret key base for session encryption"
  type        = string
  sensitive   = true
}
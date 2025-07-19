variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "region" {
  description = "Region for Cloud Run services"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
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
}

variable "service_account" {
  description = "Service account email for Cloud Run"
  type        = string
}

variable "artifact_registry" {
  description = "Artifact Registry repository ID"
  type        = string
}

variable "env_vars" {
  description = "Environment variables for all services"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Secret Manager secrets to mount"
  type        = map(string)
  default     = {}
}
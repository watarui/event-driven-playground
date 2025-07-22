variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "firebase_api_key" {
  description = "Firebase API key"
  type        = string
  sensitive   = true
}

variable "secret_key_base" {
  description = "Secret key base for Phoenix"
  type        = string
  sensitive   = true
}
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "supabase_url" {
  description = "Supabase database URL"
  type        = string
  sensitive   = true
}

variable "supabase_service_key" {
  description = "Supabase service role key"
  type        = string
  sensitive   = true
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
# Cloud Run URL は Cloud Run モジュールを有効化した後に利用可能になります
# output "cloud_run_urls" {
#   description = "URLs of deployed Cloud Run services"
#   value = module.cloud_run.service_urls
# }

output "pubsub_topics" {
  description = "Created Pub/Sub topics"
  value = module.pubsub.topics
}

output "artifact_registry_url" {
  description = "URL of the Artifact Registry"
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.event_driven_playground.repository_id}"
}

output "service_account_email" {
  description = "Email of the Cloud Run service account"
  value = google_service_account.cloud_run_sa.email
}

output "firebase_project_id" {
  description = "Firebase project ID"
  value = var.firebase_config.project_id
  sensitive = true
}

output "deployment_commands" {
  description = "Commands to deploy services"
  value = {
    build_and_push = <<-EOT
      # Build and push Docker images
      export REGISTRY_URL="${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.event_driven_playground.repository_id}"
      
      # Authenticate with Artifact Registry
      gcloud auth configure-docker ${var.region}-docker.pkg.dev
      
      # Build and push each service
      for service in command-service query-service client-service; do
        docker build -f apps/$${service//-/_}/Dockerfile -t $$REGISTRY_URL/$$service:latest .
        docker push $$REGISTRY_URL/$$service:latest
      done
    EOT
    
    deploy_services = <<-EOT
      # Deploy services to Cloud Run
      terraform apply -auto-approve
    EOT
  }
}
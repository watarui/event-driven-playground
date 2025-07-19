output "service_urls" {
  description = "URLs of deployed services"
  value = {
    for k, v in google_cloud_run_v2_service.services : k => v.uri
  }
}

output "service_names" {
  description = "Names of deployed services"
  value = {
    for k, v in google_cloud_run_v2_service.services : k => v.name
  }
}
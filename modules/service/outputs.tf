output "name" {
  description = "Service name."
  value       = google_cloud_run_v2_service.this.name
}

output "url" {
  description = "HTTPS URL of the service."
  value       = google_cloud_run_v2_service.this.uri
}

output "runtime_service_account" {
  description = "Email of the identity the containers run as."
  value       = google_service_account.runtime.email
}

output "url" {
  description = "Docker repository URL, e.g. europe-west1-docker.pkg.dev/project/model-server."
  value       = "${var.location}-docker.pkg.dev/${var.project}/${google_artifact_registry_repository.this.repository_id}"
}

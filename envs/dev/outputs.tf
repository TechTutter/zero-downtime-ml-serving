output "service_url" {
  description = "Model server URL."
  value       = module.service.url
}

output "registry_url" {
  description = "Artifact Registry repository for promoted images."
  value       = module.registry.url
}

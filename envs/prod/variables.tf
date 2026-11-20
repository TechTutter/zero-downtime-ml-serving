variable "project_id" {
  description = "Project created by bootstrap for this environment."
  type        = string
}

variable "region" {
  description = "Region for every regional resource."
  type        = string
  default     = "europe-west1"
}

variable "bootstrap_image" {
  description = "Placeholder image for the very first revision, before CI deploys the model server."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello@sha256:04e460afdf4c4c8e615b809d3b41249f89af11ef5358a81fc62b3f09a70c6169"
}

variable "public" {
  description = "Allow unauthenticated requests."
  type        = bool
}

variable "invokers" {
  description = "IAM members allowed to call a private service."
  type        = list(string)
  default     = []
}

variable "min_instances" {
  description = "Warm instances per revision."
  type        = number
}

variable "max_instances" {
  description = "Instance cap, also a cost guard."
  type        = number
}

variable "deletion_protection" {
  description = "Protect the service from terraform destroy."
  type        = bool
}

variable "registry_readers" {
  description = "Extra IAM members allowed to pull from this environment's registry."
  type        = list(string)
  default     = []
}

variable "alert_emails" {
  description = "Who gets paged."
  type        = list(string)
  default     = []
}

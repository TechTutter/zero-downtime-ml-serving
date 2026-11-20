variable "project" {
  description = "Project that runs the service."
  type        = string
}

variable "region" {
  description = "Cloud Run region."
  type        = string
}

variable "name" {
  description = "Service name."
  type        = string
  default     = "model-server"
}

variable "image" {
  description = "Image for the first revision only; later revisions are deployed by CI."
  type        = string
}

variable "deployer_member" {
  description = "IAM member of the CI deployer, allowed to act as the runtime SA."
  type        = string
}

variable "public" {
  description = "Allow unauthenticated invocations."
  type        = bool
  default     = false
}

variable "invokers" {
  description = "IAM members allowed to invoke a non-public service."
  type        = list(string)
  default     = []
}

variable "min_instances" {
  description = "Warm instances kept per revision (0 scales to zero)."
  type        = number
  default     = 0

  validation {
    condition     = var.min_instances <= var.max_instances
    error_message = "min_instances must not exceed max_instances."
  }
}

variable "max_instances" {
  description = "Upper bound on instances, also a cost guard."
  type        = number
  default     = 3
}

variable "concurrency" {
  description = "Concurrent requests per instance."
  type        = number
  default     = 40
}

variable "cpu" {
  description = "CPU limit per instance."
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Memory limit per instance."
  type        = string
  default     = "512Mi"
}

variable "deletion_protection" {
  description = "Block terraform destroy of the service."
  type        = bool
  default     = true
}

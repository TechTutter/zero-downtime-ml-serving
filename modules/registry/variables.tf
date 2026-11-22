variable "project" {
  description = "Project that owns the repository."
  type        = string
}

variable "location" {
  description = "Repository region."
  type        = string
}

variable "repository_id" {
  description = "Repository name."
  type        = string
  default     = "model-server"
}

variable "writers" {
  description = "IAM members allowed to push (the deployer copies promoted images here)."
  type        = list(string)
  default     = []
}

variable "readers" {
  description = "IAM members allowed to pull, e.g. the prod deployer reading from dev."
  type        = list(string)
  default     = []
}

variable "keep_count" {
  description = <<-EOT
    Most recent versions kept. Each release is two versions (image + cosign signature),
    so 4 keeps the current release and the previous one, the rollback target. Deliberately
    minimal to stay inside the 0.5 GB Artifact Registry free tier.
  EOT
  type        = number
  default     = 4
}

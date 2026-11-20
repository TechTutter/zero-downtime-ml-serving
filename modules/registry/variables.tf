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
  description = "Most recent image versions always kept by the cleanup policy."
  type        = number
  default     = 10
}

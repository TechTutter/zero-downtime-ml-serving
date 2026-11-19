variable "billing_account" {
  description = "Billing account ID (XXXXXX-XXXXXX-XXXXXX) the new projects are linked to."
  type        = string
}

variable "admin_project" {
  description = "Existing project used as quota project for billing and resource-manager API calls."
  type        = string
}

variable "project_prefix" {
  description = "Projects are created as <prefix>-dev and <prefix>-prod. Must be globally unique."
  type        = string
}

variable "region" {
  description = "Region for state buckets and, by convention, all regional resources."
  type        = string
  default     = "europe-west1"
}

variable "github_repository" {
  description = "owner/name of the only repository allowed to federate into these projects."
  type        = string
  default     = "TechTutter/zero-downtime-ml-serving"
}

variable "budget_amount" {
  description = "Monthly budget per project, in the billing account currency."
  type        = number
  default     = 20
}

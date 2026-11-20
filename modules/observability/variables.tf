variable "project" {
  description = "Project that runs the service."
  type        = string
}

variable "service_name" {
  description = "Cloud Run service to observe."
  type        = string
}

variable "service_url" {
  description = "HTTPS URL of the service, for the uptime check."
  type        = string
}

variable "public" {
  description = "Whether the service is reachable from the internet (enables the uptime check)."
  type        = bool
}

variable "alert_emails" {
  description = "Email addresses notified by alerts."
  type        = list(string)
  default     = []
}

variable "availability_goal" {
  description = "Request-based availability SLO over 28 days."
  type        = number
  default     = 0.995
}

variable "max_error_ratio" {
  description = "5xx ratio that pages. Same threshold the canary analysis uses."
  type        = number
  default     = 0.05
}

variable "max_p99_ms" {
  description = "p99 latency that pages, in milliseconds. Same threshold the canary uses."
  type        = number
  default     = 500
}

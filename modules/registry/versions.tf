terraform {
  required_version = ">= 1.9, < 2.0" # mock_provider tests, cross-variable validation
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.10.0"
    }
  }
}

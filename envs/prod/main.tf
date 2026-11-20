# Same composition in every environment; only terraform.tfvars differs.

terraform {
  # bucket is passed at init: terraform init -backend-config="bucket=<project>-tfstate"
  backend "gcs" {
    prefix = "envs"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  deployer = "serviceAccount:deployer@${var.project_id}.iam.gserviceaccount.com"
}

module "registry" {
  source = "../../modules/registry"

  project  = var.project_id
  location = var.region
  writers  = [local.deployer]
  readers  = var.registry_readers
}

module "service" {
  source = "../../modules/service"

  project             = var.project_id
  region              = var.region
  image               = var.bootstrap_image
  deployer_member     = local.deployer
  public              = var.public
  invokers            = var.invokers
  min_instances       = var.min_instances
  max_instances       = var.max_instances
  deletion_protection = var.deletion_protection
}

module "observability" {
  source = "../../modules/observability"

  project      = var.project_id
  service_name = module.service.name
  service_url  = module.service.url
  public       = var.public
  alert_emails = var.alert_emails
}

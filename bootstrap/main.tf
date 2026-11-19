# One-time setup, applied by hand with local state (it creates the state buckets).
# Everything CI needs to reach GCP without keys: projects, WIF, least-privilege service accounts.

provider "google" {
  region                = var.region
  billing_project       = var.admin_project
  user_project_override = true
}

locals {
  envs = toset(["dev", "prod"])
  apis = toset([
    "artifactregistry.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "monitoring.googleapis.com",
    "run.googleapis.com",
    "serviceusage.googleapis.com",
    "sts.googleapis.com",
  ])
  project_apis = { for pair in setproduct(local.envs, local.apis) : "${pair[0]}/${pair[1]}" => pair }

  # Roles per CI identity. Plan reads, apply manages the stack, deployer only ships revisions.
  roles = {
    tf-plan = ["roles/viewer", "roles/iam.securityReviewer"]
    tf-apply = [
      "roles/viewer",
      "roles/run.admin",
      "roles/artifactregistry.admin",
      "roles/iam.serviceAccountAdmin",
      "roles/monitoring.editor",
    ]
    deployer = ["roles/run.developer", "roles/monitoring.viewer"]
  }
  sa_roles = merge([
    for env in local.envs : {
      for item in flatten([for sa, roles in local.roles : [for r in roles : { sa = sa, role = r }]]) :
      "${env}/${item.sa}/${item.role}" => merge(item, { env = env })
    }
  ]...)
  env_sas = { for pair in setproduct(local.envs, keys(local.roles)) : "${pair[0]}/${pair[1]}" => { env = pair[0], sa = pair[1] } }
}

resource "google_project" "env" {
  for_each = local.envs

  project_id      = "${var.project_prefix}-${each.key}"
  name            = "${var.project_prefix}-${each.key}"
  billing_account = var.billing_account
  deletion_policy = "DELETE"
  labels          = { env = each.key, managed-by = "terraform" }
}

resource "google_project_service" "api" {
  for_each = local.project_apis

  project            = google_project.env[each.value[0]].project_id
  service            = each.value[1]
  disable_on_destroy = false
}

resource "google_storage_bucket" "tfstate" {
  for_each = local.envs

  project                     = google_project.env[each.key].project_id
  name                        = "${google_project.env[each.key].project_id}-tfstate"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = each.key == "dev" # dev is destroyed after the demo

  versioning {
    enabled = true
  }
}

# ---- Workload Identity Federation: GitHub OIDC tokens, this repository only ----

resource "google_iam_workload_identity_pool" "github" {
  for_each = local.envs

  project                   = google_project.env[each.key].project_id
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"
  depends_on                = [google_project_service.api]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  for_each = local.envs

  project                            = google_project.env[each.key].project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github[each.key].workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub OIDC"
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }
  # Tokens from any other repository are rejected before any IAM binding is evaluated.
  attribute_condition = "assertion.repository == '${var.github_repository}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "ci" {
  for_each = local.env_sas

  project      = google_project.env[each.value.env].project_id
  account_id   = each.value.sa
  display_name = "GitHub Actions ${each.value.sa}"
  depends_on   = [google_project_service.api]
}

resource "google_project_iam_member" "ci" {
  for_each = local.sa_roles

  project = google_project.env[each.value.env].project_id
  role    = each.value.role
  member  = google_service_account.ci["${each.value.env}/${each.value.sa}"].member
}

# Plan and apply hold the state lock, so both need object access on the state bucket.
resource "google_storage_bucket_iam_member" "tfstate" {
  for_each = { for k, v in local.env_sas : k => v if v.sa != "deployer" }

  bucket = google_storage_bucket.tfstate[each.value.env].name
  role   = "roles/storage.objectUser"
  member = google_service_account.ci[each.key].member
}

# Who may impersonate what:
# - tf-plan: any workflow of the repository (pull requests run plans).
# - tf-apply and deployer: only jobs running in the matching GitHub environment, where
#   protection rules (prod: required reviewers) apply.
resource "google_service_account_iam_member" "wif" {
  for_each = local.env_sas

  service_account_id = google_service_account.ci[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member = (
    each.value.sa == "tf-plan"
    ? "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github[each.value.env].name}/attribute.repository/${var.github_repository}"
    : "principal://iam.googleapis.com/${google_iam_workload_identity_pool.github[each.value.env].name}/subject/repo:${var.github_repository}:environment:${each.value.env}"
  )
}

resource "google_billing_budget" "env" {
  for_each = local.envs

  billing_account = var.billing_account
  display_name    = "${google_project.env[each.key].project_id} monthly"

  budget_filter {
    projects = ["projects/${google_project.env[each.key].number}"]
  }

  amount {
    specified_amount {
      units = tostring(var.budget_amount)
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.9
  }
  threshold_rules {
    threshold_percent = 1.0
  }
}

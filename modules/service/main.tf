# The model server on Cloud Run. Terraform owns the service shape; CI owns revisions
# (image, env, traffic split), so those fields are ignored after creation.

resource "google_service_account" "runtime" {
  project      = var.project
  account_id   = "${var.name}-run"
  display_name = "${var.name} runtime (no project roles)"
}

resource "google_cloud_run_v2_service" "this" {
  project             = var.project
  name                = var.name
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = var.deletion_protection

  template {
    service_account                  = google_service_account.runtime.email
    max_instance_request_concurrency = var.concurrency
    timeout                          = "30s"

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    containers {
      image = var.image

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
        cpu_idle          = true
        startup_cpu_boost = true
      }

      startup_probe {
        period_seconds    = 2
        failure_threshold = 30
        http_get {
          path = "/readyz"
        }
      }

      liveness_probe {
        period_seconds = 10
        http_get {
          path = "/healthz"
        }
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      template[0].containers[0].env,
      template[0].revision,
      template[0].labels,
      traffic,
      client,
      client_version,
    ]
  }
}

# Demo environments are public; anything else lists its invokers explicitly.
resource "google_cloud_run_v2_service_iam_member" "public" {
  count = var.public ? 1 : 0

  project  = var.project
  location = var.region
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "invoker" {
  for_each = toset(var.invokers)

  project  = var.project
  location = var.region
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  member   = each.value
}

# Deploying a revision means running as the runtime SA: grant that on this SA only.
resource "google_service_account_iam_member" "deployer_act_as" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = var.deployer_member
}

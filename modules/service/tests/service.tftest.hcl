mock_provider "google" {}

variables {
  project         = "demo-dev"
  region          = "europe-west1"
  image           = "us-docker.pkg.dev/cloudrun/container/hello"
  deployer_member = "serviceAccount:deployer@demo-dev.iam.gserviceaccount.com"
}

run "private_by_default" {
  command = plan

  assert {
    condition     = length(google_cloud_run_v2_service_iam_member.public) == 0
    error_message = "A service must not be public unless asked."
  }
}

run "public_service_allows_all_users" {
  command = plan

  variables {
    public = true
  }

  assert {
    condition     = google_cloud_run_v2_service_iam_member.public[0].member == "allUsers"
    error_message = "Public service should grant run.invoker to allUsers."
  }
}

run "scaling_and_probes" {
  command = plan

  variables {
    min_instances = 1
    max_instances = 5
  }

  assert {
    condition     = google_cloud_run_v2_service.this.template[0].scaling[0].max_instance_count == 5
    error_message = "max_instances not applied."
  }

  assert {
    condition     = google_cloud_run_v2_service.this.template[0].containers[0].startup_probe[0].http_get[0].path == "/readyz"
    error_message = "Startup probe must gate traffic on readiness."
  }
}

run "deployer_can_act_as_runtime_sa_only" {
  command = plan

  assert {
    condition     = google_service_account_iam_member.deployer_act_as.role == "roles/iam.serviceAccountUser"
    error_message = "Deployer needs actAs on the runtime SA."
  }
}

run "rejects_min_above_max" {
  command = plan

  variables {
    min_instances = 4
    max_instances = 2
  }

  expect_failures = [var.min_instances]
}

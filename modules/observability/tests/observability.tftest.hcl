mock_provider "google" {}

variables {
  project      = "demo-dev"
  service_name = "model-server"
  service_url  = "https://model-server-abc-ew.a.run.app"
}

run "uptime_check_only_when_public" {
  command = plan

  variables {
    public = false
  }

  assert {
    condition     = length(google_monitoring_uptime_check_config.healthz) == 0
    error_message = "Private services cannot be probed from the internet."
  }
}

run "uptime_check_targets_host" {
  command = plan

  variables {
    public = true
  }

  assert {
    condition     = google_monitoring_uptime_check_config.healthz[0].monitored_resource[0].labels.host == "model-server-abc-ew.a.run.app"
    error_message = "Uptime check host must not include the scheme."
  }
}

run "alerts_match_canary_thresholds" {
  command = plan

  variables {
    public = true
  }

  assert {
    condition     = google_monitoring_alert_policy.error_ratio.conditions[0].condition_threshold[0].threshold_value == 0.05
    error_message = "Alert and canary must agree on what a bad error rate is."
  }
}

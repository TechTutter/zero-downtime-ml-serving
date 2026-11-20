# What on-call looks at: an availability SLO, alerts on the same signals the canary uses,
# an uptime check and a dashboard split by revision (so a canary is visible next to stable).

locals {
  run_filter = "resource.type = \"cloud_run_revision\" AND resource.labels.service_name = \"${var.service_name}\""
  requests   = "${local.run_filter} AND metric.type = \"run.googleapis.com/request_count\""
  errors     = "${local.requests} AND metric.labels.response_code_class = \"5xx\""
  latency    = "${local.run_filter} AND metric.type = \"run.googleapis.com/request_latencies\""
  channels   = [for c in google_monitoring_notification_channel.email : c.id]
}

resource "google_monitoring_notification_channel" "email" {
  for_each = toset(var.alert_emails)

  project      = var.project
  display_name = "On-call ${each.value}"
  type         = "email"
  labels       = { email_address = each.value }
}

resource "google_monitoring_custom_service" "this" {
  project      = var.project
  service_id   = var.service_name
  display_name = var.service_name
}

resource "google_monitoring_slo" "availability" {
  project      = var.project
  service      = google_monitoring_custom_service.this.service_id
  slo_id       = "availability"
  display_name = "${var.availability_goal * 100}% of requests succeed (28d)"

  goal                = var.availability_goal
  rolling_period_days = 28

  request_based_sli {
    good_total_ratio {
      bad_service_filter   = local.errors
      total_service_filter = local.requests
    }
  }
}

resource "google_monitoring_alert_policy" "error_ratio" {
  project               = var.project
  display_name          = "${var.service_name}: 5xx ratio above ${var.max_error_ratio * 100}%"
  combiner              = "OR"
  notification_channels = local.channels

  conditions {
    display_name = "5xx / all requests"
    condition_threshold {
      filter             = local.errors
      denominator_filter = local.requests
      comparison         = "COMPARISON_GT"
      threshold_value    = var.max_error_ratio
      duration           = "300s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
      denominator_aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  documentation {
    content   = "Runbook: docs/runbook.md#high-error-rate"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "latency" {
  project               = var.project
  display_name          = "${var.service_name}: p99 latency above ${var.max_p99_ms}ms"
  combiner              = "OR"
  notification_channels = local.channels

  conditions {
    display_name = "p99 request latency"
    condition_threshold {
      filter          = local.latency
      comparison      = "COMPARISON_GT"
      threshold_value = var.max_p99_ms
      duration        = "300s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_PERCENTILE_99"
        cross_series_reducer = "REDUCE_MAX"
      }
    }
  }

  documentation {
    content   = "Runbook: docs/runbook.md#high-latency"
    mime_type = "text/markdown"
  }
}

# Uptime checks probe from the internet, so they only make sense for a public service.
resource "google_monitoring_uptime_check_config" "healthz" {
  count = var.public ? 1 : 0

  project      = var.project
  display_name = "${var.service_name} /healthz"
  timeout      = "10s"
  period       = "60s"

  http_check {
    path         = "/healthz"
    port         = 443
    use_ssl      = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project
      host       = trimprefix(var.service_url, "https://")
    }
  }
}

resource "google_monitoring_dashboard" "this" {
  project = var.project
  dashboard_json = jsonencode({
    displayName = "${var.service_name} rollout"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          width = 12, height = 4, xPos = 0, yPos = 0
          widget = {
            title = "Requests per second by revision and status class"
            xyChart = {
              dataSets = [{
                plotType = "STACKED_AREA"
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = local.requests
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["resource.label.revision_name", "metric.label.response_code_class"]
                    }
                  }
                }
              }]
            }
          }
        },
        {
          width = 6, height = 4, xPos = 0, yPos = 4
          widget = {
            title = "5xx per second by revision"
            xyChart = {
              dataSets = [{
                plotType = "LINE"
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = local.errors
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["resource.label.revision_name"]
                    }
                  }
                }
              }]
            }
          }
        },
        {
          width = 6, height = 4, xPos = 6, yPos = 4
          widget = {
            title = "p99 latency (ms) by revision"
            xyChart = {
              dataSets = [{
                plotType = "LINE"
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = local.latency
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_PERCENTILE_99"
                      crossSeriesReducer = "REDUCE_MAX"
                      groupByFields      = ["resource.label.revision_name"]
                    }
                  }
                }
              }]
            }
          }
        },
      ]
    }
  })
}

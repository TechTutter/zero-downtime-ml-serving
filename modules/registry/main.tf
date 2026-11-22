resource "google_artifact_registry_repository" "this" {
  project       = var.project
  location      = var.location
  repository_id = var.repository_id
  format        = "DOCKER"
  description   = "Model server images, promoted here by digest."

  # A tag can never be moved to a different image; releases are addressed by digest anyway.
  docker_config {
    immutable_tags = true
  }

  # Delete everything except the most recent versions (KEEP wins over DELETE).
  # Cleanup runs about once a day, so the repository can briefly exceed keep_count.
  cleanup_policies {
    id     = "delete-all"
    action = "DELETE"
    condition {
      tag_state = "ANY"
    }
  }

  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions {
      keep_count = var.keep_count
    }
  }
}

resource "google_artifact_registry_repository_iam_member" "writer" {
  for_each = toset(var.writers)

  project    = var.project
  location   = var.location
  repository = google_artifact_registry_repository.this.name
  role       = "roles/artifactregistry.writer"
  member     = each.value
}

resource "google_artifact_registry_repository_iam_member" "reader" {
  for_each = toset(var.readers)

  project    = var.project
  location   = var.location
  repository = google_artifact_registry_repository.this.name
  role       = "roles/artifactregistry.reader"
  member     = each.value
}

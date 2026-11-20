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

  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions {
      keep_count = var.keep_count
    }
  }

  cleanup_policies {
    id     = "delete-old-untagged"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "604800s" # 7 days
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

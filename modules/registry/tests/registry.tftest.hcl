mock_provider "google" {}

variables {
  project  = "demo-dev"
  location = "europe-west1"
  writers  = ["serviceAccount:deployer@demo-dev.iam.gserviceaccount.com"]
}

run "tags_are_immutable" {
  command = plan

  assert {
    condition     = google_artifact_registry_repository.this.docker_config[0].immutable_tags
    error_message = "Promotion by digest relies on tags never moving."
  }
}

run "writers_and_readers_get_separate_roles" {
  command = plan

  variables {
    readers = ["serviceAccount:deployer@demo-prod.iam.gserviceaccount.com"]
  }

  assert {
    condition     = length(google_artifact_registry_repository_iam_member.writer) == 1 && length(google_artifact_registry_repository_iam_member.reader) == 1
    error_message = "Expected one writer and one reader binding."
  }
}

run "url_format" {
  command = plan

  assert {
    condition     = output.url == "europe-west1-docker.pkg.dev/demo-dev/model-server"
    error_message = "Unexpected repository URL."
  }
}

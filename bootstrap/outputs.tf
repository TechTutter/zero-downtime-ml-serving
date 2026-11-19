# Repository variables for GitHub Actions (not secrets). tools/gh-vars.sh sets them.
output "github_variables" {
  value = merge(
    { GCP_REGION = var.region },
    merge([
      for env in local.envs : {
        "GCP_PROJECT_${upper(env)}"      = google_project.env[env].project_id
        "GCP_WIF_PROVIDER_${upper(env)}" = google_iam_workload_identity_pool_provider.github[env].name
        "GCP_SA_PLAN_${upper(env)}"      = google_service_account.ci["${env}/tf-plan"].email
        "GCP_SA_APPLY_${upper(env)}"     = google_service_account.ci["${env}/tf-apply"].email
        "GCP_SA_DEPLOYER_${upper(env)}"  = google_service_account.ci["${env}/deployer"].email
        "TF_STATE_BUCKET_${upper(env)}"  = google_storage_bucket.tfstate[env].name
      }
    ]...)
  )
}

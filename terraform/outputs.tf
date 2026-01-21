# Outputs for the Cloud Build CI/CD infrastructure

output "cloud_build_service_account" {
  description = "Email of the Cloud Build service account"
  value       = google_service_account.cloud_build_sa.email
}

output "cloud_run_service_account" {
  description = "Email of the Cloud Run service account"
  value       = google_service_account.cloud_run_sa.email
}

output "log_bucket_name" {
  description = "Name of the centralized log bucket"
  value       = google_logging_project_bucket_config.cloud_build_logs.bucket_id
}

output "monitoring_dashboard_url" {
  description = "URL to the monitoring dashboard"
  value       = var.enable_monitoring ? "https://console.cloud.google.com/monitoring/dashboards/custom/${google_monitoring_dashboard.cloud_build_dashboard[0].id}?project=${var.project_id}" : "Monitoring disabled"
}

output "cloud_build_trigger_instructions" {
  description = "Instructions for setting up Cloud Build trigger"
  value       = <<-EOT
    To set up Cloud Build trigger, run:
    
    gcloud builds triggers create github \
      --repo-name=${var.repository_name} \
      --repo-owner=YOUR_GITHUB_ORG \
      --branch-pattern="^main$" \
      --build-config=cloudbuild.yaml \
      --service-account=projects/${var.project_id}/serviceAccounts/${google_service_account.cloud_build_sa.email}
  EOT
}

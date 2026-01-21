# IAM Configuration for Cloud Build Pipeline
# This file defines service accounts and IAM bindings with least privilege

# Service Account for Cloud Build
resource "google_service_account" "cloud_build_sa" {
  account_id   = "cloud-build-sa"
  display_name = "Cloud Build Service Account"
  description  = "Service account for Cloud Build with minimal required permissions"
}

# Service Account for Cloud Run
resource "google_service_account" "cloud_run_sa" {
  account_id   = "cloud-run-sa"
  display_name = "Cloud Run Service Account"
  description  = "Service account for Cloud Run services"
}

# IAM Bindings for Cloud Build Service Account
# Grant Cloud Build service account permissions to build and deploy

# Permission to push images to Container Registry
resource "google_project_iam_member" "cloud_build_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.cloud_build_sa.email}"
  
  condition {
    title       = "Storage access for GCR only"
    description = "Restrict storage access to Container Registry buckets"
    expression  = "resource.name.startsWith('projects/_/buckets/artifacts.${var.project_id}.appspot.com') || resource.name.startsWith('projects/_/buckets/${var.project_id}.appspot.com')"
  }
}

# Permission to deploy to Cloud Run
resource "google_project_iam_member" "cloud_build_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.cloud_build_sa.email}"
}

# Permission to act as Cloud Run service account
resource "google_service_account_iam_member" "cloud_build_sa_user" {
  service_account_id = google_service_account.cloud_run_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.cloud_build_sa.email}"
}

# Permission to write logs
resource "google_project_iam_member" "cloud_build_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloud_build_sa.email}"
}

# Permission to view and scan container images
resource "google_project_iam_member" "cloud_build_artifact_registry_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.cloud_build_sa.email}"
}

# Grant the default Cloud Build service account necessary permissions
resource "google_project_iam_member" "cloudbuild_builds_builder" {
  project = var.project_id
  role    = "roles/cloudbuild.builds.builder"
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

# Data source to get project number
data "google_project" "project" {
  project_id = var.project_id
}

# IAM Bindings for Cloud Run Service Account
# Minimal permissions for the running application

# Permission to write logs from Cloud Run
resource "google_project_iam_member" "cloud_run_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Permission to write metrics from Cloud Run
resource "google_project_iam_member" "cloud_run_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

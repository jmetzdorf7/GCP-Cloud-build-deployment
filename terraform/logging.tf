# Logging Configuration for Cloud Build Pipeline
# Centralized logging with log sinks and retention policies

# Log bucket for Cloud Build logs
resource "google_logging_project_bucket_config" "cloud_build_logs" {
  project        = var.project_id
  location       = "global"
  bucket_id      = "cloud-build-logs"
  retention_days = var.log_retention_days
  description    = "Centralized log bucket for Cloud Build CI/CD pipeline"
}

# Log sink for Cloud Build logs
resource "google_logging_project_sink" "cloud_build_sink" {
  name        = "cloud-build-logs-sink"
  description = "Sink for Cloud Build logs to centralized bucket"
  
  destination = "logging.googleapis.com/projects/${var.project_id}/locations/global/buckets/${google_logging_project_bucket_config.cloud_build_logs.bucket_id}"
  
  # Filter for Cloud Build logs
  filter = "resource.type=\"build\" OR resource.type=\"cloud_build\""
  
  # Use unique writer identity
  unique_writer_identity = true
}

# Log sink for Cloud Run logs
resource "google_logging_project_sink" "cloud_run_sink" {
  name        = "cloud-run-logs-sink"
  description = "Sink for Cloud Run application logs"
  
  destination = "logging.googleapis.com/projects/${var.project_id}/locations/global/buckets/${google_logging_project_bucket_config.cloud_build_logs.bucket_id}"
  
  # Filter for Cloud Run logs
  filter = "resource.type=\"cloud_run_revision\""
  
  # Use unique writer identity
  unique_writer_identity = true
}

# Grant log writer permissions to the sink
resource "google_project_iam_member" "log_sink_writer" {
  project = var.project_id
  role    = "roles/logging.bucketWriter"
  member  = google_logging_project_sink.cloud_build_sink.writer_identity
}

resource "google_project_iam_member" "log_sink_writer_cloud_run" {
  project = var.project_id
  role    = "roles/logging.bucketWriter"
  member  = google_logging_project_sink.cloud_run_sink.writer_identity
}

# Log metric for build failures
resource "google_logging_metric" "build_failures" {
  name        = "cloud_build_failures"
  description = "Count of failed Cloud Build executions"
  filter      = "resource.type=\"build\" AND severity=\"ERROR\""
  
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
    
    labels {
      key         = "build_id"
      value_type  = "STRING"
      description = "Build ID"
    }
  }
  
  label_extractors = {
    "build_id" = "EXTRACT(resource.labels.build_id)"
  }
}

# Log metric for deployment success
resource "google_logging_metric" "deployment_success" {
  name        = "cloud_build_deployments"
  description = "Count of successful deployments"
  filter      = "resource.type=\"build\" AND textPayload=~\"DONE\" AND severity=\"INFO\""
  
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }
}

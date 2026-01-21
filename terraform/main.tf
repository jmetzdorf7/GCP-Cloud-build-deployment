# Terraform configuration for GCP Cloud Build CI/CD Pipeline
# This configuration sets up IAM roles, logging, and monitoring

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  
  # Uncomment to use remote state
  # backend "gcs" {
  #   bucket = "your-terraform-state-bucket"
  #   prefix = "cloud-build-pipeline"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# GCP Cloud Build CI/CD Pipeline

A secure CI/CD pipeline implementation using Google Cloud Build with IAM roles, centralized logging, and monitoring.

## Overview

This repository demonstrates a production-ready CI/CD pipeline for GCP using Cloud Build with:
- **Secure IAM roles** with least privilege principle
- **Centralized logging** to Cloud Logging with retention policies
- **Monitoring and alerting** using Cloud Monitoring
- **Security scanning** for container images
- **Automated deployment** to Cloud Run

## Architecture

The pipeline includes:
1. **Cloud Build** - Automated build and deployment
2. **Service Accounts** - Separate accounts for Cloud Build and Cloud Run with minimal permissions
3. **IAM Roles** - Fine-grained access control
4. **Cloud Logging** - Centralized log collection with retention policies
5. **Cloud Monitoring** - Dashboards and alerts for pipeline health
6. **Container Registry** - Secure image storage

## Prerequisites

- Google Cloud Platform account
- `gcloud` CLI installed and configured
- Terraform >= 1.0
- GitHub repository connected to Cloud Build (optional)

## Quick Start

### 1. Configure GCP Project

```bash
# Set your project ID
export PROJECT_ID="landingzone-cloud-build-primary"
gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable logging.googleapis.com
gcloud services enable monitoring.googleapis.com
```

### 2. Deploy Infrastructure with Terraform

```bash
cd terraform

# Copy example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
# At minimum, set: project_id

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

### 3. Set Up Cloud Build Trigger

After Terraform deployment, set up a Cloud Build trigger:

```bash
# Get the service account email from Terraform output
terraform output cloud_build_service_account

# Create a Cloud Build trigger (if using GitHub)
gcloud builds triggers create github \
  --repo-name=GCP-Cloud-build-deployment \
  --repo-owner=YOUR_GITHUB_USERNAME \
  --branch-pattern="^main$" \
  --build-config=cloudbuild.yaml \
  --service-account="$(terraform output -raw cloud_build_service_account)"
```

### 4. Test the Pipeline

Trigger a build manually:

```bash
gcloud builds submit --config=cloudbuild.yaml
```

## Security Features

### IAM Roles and Service Accounts

The infrastructure creates two service accounts with minimal permissions:

1. **Cloud Build Service Account** (`cloud-build-sa`)
   - Storage admin (limited to Container Registry buckets)
   - Cloud Run admin
   - Service account user for Cloud Run SA
   - Log writer
   - Artifact Registry reader

2. **Cloud Run Service Account** (`cloud-run-sa`)
   - Log writer
   - Metric writer

### Security Scanning

The pipeline includes automatic container image scanning:
- Vulnerability detection before deployment
- Integration with Container Analysis API
- Automated scanning on each build

### Access Control

- Service accounts use least privilege principle
- IAM conditions restrict storage access to Container Registry only
- No overly permissive roles granted

## Logging

### Centralized Log Collection

- **Log Bucket**: `cloud-build-logs` with configurable retention (default: 30 days)
- **Log Sinks**: Separate sinks for Cloud Build and Cloud Run logs
- **Log Metrics**: Custom metrics for build failures and deployments

### Viewing Logs

```bash
# View Cloud Build logs
gcloud logging read "resource.type=build" --limit=50

# View Cloud Run logs
gcloud logging read "resource.type=cloud_run_revision" --limit=50

# View logs in the centralized bucket
gcloud logging read "logName:projects/${PROJECT_ID}/locations/global/buckets/cloud-build-logs" --limit=50
```

## Monitoring

### Dashboards

Access the monitoring dashboard (URL provided in Terraform outputs):
- Build success rate
- Build duration
- Cloud Run request count
- Response latency

```bash
# Get dashboard URL
terraform output monitoring_dashboard_url
```

### Alerts

The infrastructure creates alert policies for:
1. **Build Failures**: Triggers when a build fails
2. **Cloud Run Errors**: Triggers when 5xx error rate is high

Configure email notifications by setting `alert_email` in `terraform.tfvars`.

### Viewing Metrics

```bash
# View build metrics
gcloud monitoring metrics list --filter="metric.type:cloudbuild"

# View Cloud Run metrics
gcloud monitoring metrics list --filter="metric.type:run.googleapis.com"
```

## Cloud Build Pipeline

The `cloudbuild.yaml` defines the CI/CD pipeline:

1. **Build**: Create Docker image
2. **Security Scan**: Scan for vulnerabilities
3. **Push**: Upload to Container Registry
4. **Deploy**: Deploy to Cloud Run

### Customization

Edit substitutions in `cloudbuild.yaml`:

```yaml
substitutions:
  _SERVICE_NAME: 'my-app'           # Your service name
  _REGION: 'us-central1'            # Deployment region
  _MAX_INSTANCES: '10'              # Max Cloud Run instances
  _MEMORY: '512Mi'                  # Memory per instance
```

## Directory Structure

```
.
├── cloudbuild.yaml          # Cloud Build pipeline configuration
├── Dockerfile               # Sample application Dockerfile
├── package.json             # Sample Node.js application
├── server.js                # Sample application code
├── terraform/               # Infrastructure as Code
│   ├── main.tf             # Main Terraform configuration
│   ├── variables.tf        # Variable definitions
│   ├── iam.tf              # IAM roles and service accounts
│   ├── logging.tf          # Logging configuration
│   ├── monitoring.tf       # Monitoring and alerts
│   ├── outputs.tf          # Terraform outputs
│   └── terraform.tfvars.example  # Example variables file
└── README.md               # This file
```

## Best Practices

1. **Service Accounts**: Use separate service accounts for different services
2. **IAM Conditions**: Restrict access using IAM conditions
3. **Log Retention**: Set appropriate log retention policies
4. **Monitoring**: Set up alerts for critical failures
5. **Secret Management**: Use Secret Manager for sensitive data (not included in sample)
6. **Network Security**: Consider using private worker pools for additional security
7. **Image Scanning**: Always scan images before deployment

## Cleanup

To destroy all resources:

```bash
cd terraform
terraform destroy
```

## Troubleshooting

### Build Fails

1. Check Cloud Build logs:
   ```bash
   gcloud builds list --limit=5
   gcloud builds log <BUILD_ID>
   ```

2. Verify service account permissions:
   ```bash
   gcloud projects get-iam-policy $PROJECT_ID \
     --flatten="bindings[].members" \
     --filter="bindings.members:cloud-build-sa@*"
   ```

### Deployment Issues

1. Check Cloud Run logs:
   ```bash
   gcloud run services logs read <SERVICE_NAME> --limit=50
   ```

2. Verify service account:
   ```bash
   gcloud run services describe <SERVICE_NAME> --format="value(spec.template.spec.serviceAccountName)"
   ```

## Additional Resources

- [Cloud Build Documentation](https://cloud.google.com/build/docs)
- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Cloud Logging Documentation](https://cloud.google.com/logging/docs)
- [Cloud Monitoring Documentation](https://cloud.google.com/monitoring/docs)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

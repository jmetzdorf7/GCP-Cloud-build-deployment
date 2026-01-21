# Deployment Guide

This guide provides step-by-step instructions for deploying the CI/CD pipeline.

## Prerequisites

Before you begin, ensure you have:

1. **GCP Project**: A Google Cloud Platform project with billing enabled
2. **gcloud CLI**: Installed and authenticated ([Installation Guide](https://cloud.google.com/sdk/docs/install))
3. **Terraform**: Version 1.0 or higher ([Download](https://www.terraform.io/downloads))
4. **GitHub Repository**: Connected to your GCP project (if using GitHub triggers)
5. **Permissions**: Project Editor or Owner role in your GCP project

## Step 1: Prepare Your Environment

### Set GCP Project

```bash
# Set your project ID
export PROJECT_ID="your-gcp-project-id"
gcloud config set project $PROJECT_ID

# Verify project
gcloud config get-value project
```

### Clone the Repository

```bash
git clone https://github.com/jmetzdorf7/GCP-Cloud-build-deployment.git
cd GCP-Cloud-build-deployment
```

## Step 2: Enable Required APIs

Enable the necessary GCP APIs:

```bash
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable logging.googleapis.com
gcloud services enable monitoring.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable containerscanning.googleapis.com
gcloud services enable secretmanager.googleapis.com
```

## Step 3: Configure Terraform Variables

### Copy the Example Variables File

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

### Edit terraform.tfvars

Edit `terraform.tfvars` with your configuration:

```hcl
# Required
project_id = "your-gcp-project-id"

# Optional - customize as needed
region             = "us-central1"
service_name       = "my-app"
repository_name    = "GCP-Cloud-build-deployment"
enable_monitoring  = true
log_retention_days = 30

# Optional - for email alerts
# alert_email = "your-email@example.com"
```

## Step 4: Deploy Infrastructure with Terraform

### Initialize Terraform

```bash
terraform init
```

This will:
- Download required provider plugins
- Initialize the backend
- Prepare the working directory

### Review the Plan

```bash
terraform plan
```

Review the resources that will be created:
- 2 Service Accounts
- IAM bindings for least privilege access
- Log bucket and sinks
- Monitoring dashboard and alerts
- Required API enablements

### Apply the Configuration

```bash
terraform apply
```

Type `yes` when prompted to confirm.

This will create:
- Service accounts for Cloud Build and Cloud Run
- IAM roles with least privilege permissions
- Centralized logging infrastructure
- Monitoring dashboards and alert policies

### Save Terraform Outputs

```bash
# View all outputs
terraform output

# Save service account emails
terraform output cloud_build_service_account
terraform output cloud_run_service_account

# Save dashboard URL
terraform output monitoring_dashboard_url
```

## Step 5: Set Up Cloud Build Trigger (Optional)

### For GitHub Integration

```bash
# Get the Cloud Build service account
SA_EMAIL=$(terraform output -raw cloud_build_service_account)

# Create a Cloud Build trigger
gcloud builds triggers create github \
  --repo-name=GCP-Cloud-build-deployment \
  --repo-owner=YOUR_GITHUB_USERNAME \
  --branch-pattern="^main$" \
  --build-config=cloudbuild.yaml \
  --service-account="$SA_EMAIL"
```

### For Cloud Source Repositories

```bash
gcloud builds triggers create cloud-source-repositories \
  --repo=REPO_NAME \
  --branch-pattern="^main$" \
  --build-config=cloudbuild.yaml \
  --service-account="$SA_EMAIL"
```

### Manual Trigger Configuration

Alternatively, configure triggers via Cloud Console:

1. Navigate to **Cloud Build > Triggers**
2. Click **Create Trigger**
3. Configure:
   - Name: `main-branch-trigger`
   - Event: Push to branch
   - Source: Your repository
   - Branch: `^main$`
   - Build Configuration: `cloudbuild.yaml`
   - Service Account: Select the Cloud Build SA created by Terraform

## Step 6: Test the Pipeline

### Manual Build Submission

Test the pipeline with a manual build:

```bash
cd ..  # Return to repository root
gcloud builds submit --config=cloudbuild.yaml
```

### Monitor the Build

```bash
# List recent builds
gcloud builds list --limit=5

# Get build details
gcloud builds describe BUILD_ID

# Stream build logs
gcloud builds log BUILD_ID --stream
```

### Verify Deployment

If deploying to Cloud Run:

```bash
# List Cloud Run services
gcloud run services list

# Get service URL
gcloud run services describe my-app --region=us-central1 --format='value(status.url)'

# Test the endpoint
curl $(gcloud run services describe my-app --region=us-central1 --format='value(status.url)')
```

## Step 7: Verify Logging and Monitoring

### Check Logs

```bash
# View Cloud Build logs
gcloud logging read "resource.type=build" --limit=10

# View centralized logs
gcloud logging read "logName:projects/$PROJECT_ID/locations/global/buckets/cloud-build-logs" --limit=10
```

### Access Monitoring Dashboard

```bash
# Get dashboard URL
cd terraform
terraform output monitoring_dashboard_url
```

Visit the URL to view:
- Build success rate
- Build duration
- Cloud Run metrics
- Error rates

### Test Alerts

If you configured an alert email:

1. Trigger a build failure intentionally
2. Wait 1-2 minutes
3. Check your email for an alert notification

## Step 8: Customize for Your Application

### Update the Sample Application

Replace the sample application with your code:

1. Update `Dockerfile` with your application's build instructions
2. Update `package.json` (or remove for non-Node.js apps)
3. Update `server.js` with your application code
4. Update `cloudbuild.yaml` if needed

### Customize Cloud Build Steps

Edit `cloudbuild.yaml` to match your workflow:

```yaml
steps:
  # Add your custom build steps
  - name: 'gcr.io/cloud-builders/npm'
    args: ['install']
  
  - name: 'gcr.io/cloud-builders/npm'
    args: ['test']
  
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/my-app:$COMMIT_SHA', '.']
  
  # Add more steps as needed
```

### Update Substitutions

Customize the substitutions in `cloudbuild.yaml`:

```yaml
substitutions:
  _SERVICE_NAME: 'your-service-name'
  _REGION: 'your-preferred-region'
  _MAX_INSTANCES: '10'
  _MEMORY: '512Mi'
```

## Common Deployment Scenarios

### Scenario 1: Multi-Environment Deployment

Create separate triggers for different environments:

```bash
# Production trigger
gcloud builds triggers create github \
  --repo-name=GCP-Cloud-build-deployment \
  --repo-owner=YOUR_USERNAME \
  --branch-pattern="^main$" \
  --build-config=cloudbuild.yaml \
  --substitutions=_ENV=production

# Staging trigger
gcloud builds triggers create github \
  --repo-name=GCP-Cloud-build-deployment \
  --repo-owner=YOUR_USERNAME \
  --branch-pattern="^staging$" \
  --build-config=cloudbuild.yaml \
  --substitutions=_ENV=staging
```

### Scenario 2: Using Secret Manager

Add secrets to Secret Manager:

```bash
# Create a secret
echo -n "my-secret-value" | gcloud secrets create my-secret --data-file=-

# Grant access to Cloud Build SA
gcloud secrets add-iam-policy-binding my-secret \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/secretmanager.secretAccessor"
```

Update `cloudbuild.yaml`:

```yaml
availableSecrets:
  secretManager:
  - versionName: projects/$PROJECT_ID/secrets/my-secret/versions/latest
    env: 'MY_SECRET'

steps:
  - name: 'gcr.io/cloud-builders/gcloud'
    secretEnv: ['MY_SECRET']
    # Use $$MY_SECRET in your build steps
```

### Scenario 3: Private Worker Pool

For enhanced security with a private network:

```bash
# Create a VPC network
gcloud compute networks create build-network --subnet-mode=auto

# Create a private worker pool
gcloud builds worker-pools create my-pool \
  --region=us-central1 \
  --peered-network=projects/$PROJECT_ID/global/networks/build-network
```

Update `cloudbuild.yaml`:

```yaml
options:
  workerPool: 'projects/$PROJECT_ID/locations/us-central1/workerPools/my-pool'
```

## Troubleshooting

### Build Fails with Permission Errors

```bash
# Verify service account has required permissions
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:cloud-build-sa@*"

# If missing, re-apply Terraform
cd terraform
terraform apply
```

### Logs Not Appearing

```bash
# Check if logging API is enabled
gcloud services list --enabled | grep logging

# Verify log sinks
gcloud logging sinks list

# Check sink permissions
gcloud logging sinks describe cloud-build-logs-sink
```

### Terraform Apply Fails

```bash
# Check Terraform version
terraform version

# Re-initialize
terraform init -upgrade

# Validate configuration
terraform validate

# Try with detailed logging
TF_LOG=DEBUG terraform apply
```

### Container Image Scan Fails

The security scan step might fail on older Docker configurations. To make it optional:

```yaml
- name: 'gcr.io/cloud-builders/gcloud'
  id: 'security-scan'
  args:
    - 'beta'
    - 'container'
    - 'images'
    - 'scan'
    - 'gcr.io/$PROJECT_ID/$REPO_NAME:$COMMIT_SHA'
  allowFailure: true  # Add this to make scan optional
```

## Cleanup

To remove all resources:

```bash
# Destroy Terraform resources
cd terraform
terraform destroy

# Delete Cloud Build triggers
gcloud builds triggers list
gcloud builds triggers delete TRIGGER_ID
```

## Next Steps

1. **Configure Email Alerts**: Set `alert_email` in `terraform.tfvars`
2. **Add Tests**: Enhance the pipeline with automated tests
3. **Set Up Staging**: Create separate environments
4. **Enable Audit Logs**: For compliance requirements
5. **Implement Secret Manager**: For sensitive configuration
6. **Review Security**: Read `docs/SECURITY.md`
7. **Optimize Costs**: Review and adjust log retention

## Getting Help

- **Documentation**: See `docs/` directory
- **Terraform Docs**: [Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- **Cloud Build Docs**: [Official Documentation](https://cloud.google.com/build/docs)
- **GitHub Issues**: Report issues in the repository

## Additional Resources

- [Security Best Practices](docs/SECURITY.md)
- [Monitoring Guide](docs/MONITORING.md)
- [Cloud Build Documentation](https://cloud.google.com/build/docs)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)

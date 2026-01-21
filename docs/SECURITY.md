# Security Configuration

This document describes the security features implemented in the CI/CD pipeline.

## IAM Security

### Service Accounts

Two separate service accounts are created to follow the principle of least privilege:

1. **Cloud Build Service Account** (`cloud-build-sa@PROJECT_ID.iam.gserviceaccount.com`)
   - Used by Cloud Build to build and deploy applications
   - Has permissions only for required operations

2. **Cloud Run Service Account** (`cloud-run-sa@PROJECT_ID.iam.gserviceaccount.com`)
   - Used by Cloud Run services at runtime
   - Has minimal permissions (logging and metrics only)

### IAM Roles and Permissions

#### Cloud Build Service Account Permissions

| Role | Purpose | Conditions |
|------|---------|------------|
| `roles/storage.admin` | Push images to Container Registry | Limited to GCR buckets only via IAM condition |
| `roles/run.admin` | Deploy to Cloud Run | Full Cloud Run admin access |
| `roles/iam.serviceAccountUser` | Use Cloud Run service account | Only for cloud-run-sa |
| `roles/logging.logWriter` | Write build logs | No conditions |
| `roles/artifactregistry.reader` | Read container images | No conditions |

#### Cloud Run Service Account Permissions

| Role | Purpose |
|------|---------|
| `roles/logging.logWriter` | Write application logs |
| `roles/monitoring.metricWriter` | Write metrics |

### IAM Conditions

The pipeline uses IAM conditions to restrict access:

```hcl
condition {
  title       = "Storage access for GCR only"
  description = "Restrict storage access to Container Registry buckets"
  expression  = "resource.name.startsWith('projects/_/buckets/artifacts.${var.project_id}.appspot.com') || resource.name.startsWith('projects/_/buckets/${var.project_id}.appspot.com')"
}
```

This ensures the Cloud Build service account can only access Container Registry buckets, not arbitrary GCS buckets.

## Security Scanning

### Container Image Scanning

Every build includes automatic container image scanning:

```yaml
- name: 'gcr.io/cloud-builders/gcloud'
  id: 'security-scan'
  args:
    - 'beta'
    - 'container'
    - 'images'
    - 'scan'
    - 'gcr.io/$PROJECT_ID/$REPO_NAME:$COMMIT_SHA'
```

This step:
- Scans for known vulnerabilities in the container image
- Uses Google's Container Analysis API
- Fails the build if critical vulnerabilities are found (configurable)

### Best Practices Implemented

1. **Least Privilege**: Service accounts have only the permissions they need
2. **Separation of Duties**: Different service accounts for build-time and runtime
3. **No Shared Credentials**: Uses Workload Identity instead of service account keys
4. **Immutable Tags**: Uses commit SHA for image tagging
5. **Audit Logging**: All actions are logged to Cloud Logging

## Network Security

### Private Worker Pool (Optional)

For enhanced security, you can configure a private worker pool:

```yaml
options:
  workerPool: 'projects/$PROJECT_ID/locations/${_REGION}/workerPools/${_WORKER_POOL}'
```

Benefits:
- Builds run in a private network
- No internet access required (uses VPC peering)
- Better isolation from public networks

To set up a private worker pool:

```bash
gcloud builds worker-pools create POOL_NAME \
  --region=REGION \
  --peered-network=projects/PROJECT_ID/global/networks/VPC_NETWORK
```

## Secret Management

### Using Secret Manager (Recommended)

For sensitive data like API keys, use Google Secret Manager:

```yaml
availableSecrets:
  secretManager:
  - versionName: projects/$PROJECT_ID/secrets/my-secret/versions/latest
    env: 'SECRET_KEY'

steps:
  - name: 'gcr.io/cloud-builders/gcloud'
    secretEnv: ['SECRET_KEY']
    entrypoint: 'bash'
    args:
      - '-c'
      - 'echo "Using secret: $$SECRET_KEY"'
```

Grant the Cloud Build service account access:

```bash
gcloud secrets add-iam-policy-binding SECRET_NAME \
  --member="serviceAccount:cloud-build-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

## Compliance and Audit

### Audit Logs

All Cloud Build operations are logged to Cloud Audit Logs:
- Admin Activity logs (enabled by default)
- Data Access logs (can be enabled)

View audit logs:

```bash
gcloud logging read "resource.type=build" --limit=50
```

### Access Reviews

Regularly review IAM permissions:

```bash
# List all IAM bindings for Cloud Build SA
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:cloud-build-sa@*"

# List all IAM bindings for Cloud Run SA
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:cloud-run-sa@*"
```

## Security Checklist

- [x] Service accounts use least privilege principle
- [x] IAM conditions restrict storage access
- [x] Container images are scanned for vulnerabilities
- [x] No service account keys are used
- [x] All actions are logged
- [x] Monitoring alerts are configured
- [ ] Consider using private worker pool for sensitive builds
- [ ] Enable Data Access audit logs for compliance requirements
- [ ] Implement Secret Manager for sensitive credentials
- [ ] Regular IAM access reviews

## Incident Response

### Build Failures

1. Check build logs in Cloud Logging
2. Review security scan results
3. Check IAM permissions if access denied

### Security Alerts

1. Review the alert in Cloud Monitoring
2. Check audit logs for suspicious activity
3. Rotate credentials if compromise suspected
4. Update IAM policies if needed

### Compromised Service Account

If a service account is compromised:

```bash
# Disable the service account
gcloud iam service-accounts disable cloud-build-sa@PROJECT_ID.iam.gserviceaccount.com

# Create a new service account and update IAM bindings
# Re-run terraform apply to restore with new account
```

## Additional Security Resources

- [GCP IAM Best Practices](https://cloud.google.com/iam/docs/best-practices)
- [Cloud Build Security](https://cloud.google.com/build/docs/securing-builds/use-least-privilege-service-accounts)
- [Container Security](https://cloud.google.com/container-analysis/docs/container-scanning-overview)
- [Secret Manager](https://cloud.google.com/secret-manager/docs)

# Monitoring and Logging

This document describes the monitoring and logging features of the CI/CD pipeline.

## Overview

The pipeline implements comprehensive monitoring and logging using:
- **Cloud Logging** for centralized log collection
- **Cloud Monitoring** for metrics and dashboards
- **Alert Policies** for proactive notifications

## Logging Architecture

### Log Buckets

A dedicated log bucket is created for centralized log storage:

- **Bucket Name**: `cloud-build-logs`
- **Location**: Global
- **Retention**: 30 days (configurable via `log_retention_days` variable)
- **Purpose**: Centralized storage for all CI/CD pipeline logs

### Log Sinks

Two log sinks route logs to the centralized bucket:

1. **Cloud Build Logs Sink**
   - Filter: `resource.type="build" OR resource.type="cloud_build"`
   - Captures all build execution logs

2. **Cloud Run Logs Sink**
   - Filter: `resource.type="cloud_run_revision"`
   - Captures application runtime logs

### Log Metrics

Custom log-based metrics for monitoring:

1. **cloud_build_failures**
   - Tracks failed build executions
   - Filter: `resource.type="build" AND severity="ERROR"`
   - Type: Counter metric

2. **cloud_build_deployments**
   - Tracks successful deployments
   - Filter: `resource.type="build" AND textPayload=~"DONE" AND severity="INFO"`
   - Type: Counter metric

## Viewing Logs

### Using gcloud CLI

```bash
# View recent Cloud Build logs
gcloud logging read "resource.type=build" \
  --limit=50 \
  --format="table(timestamp,severity,textPayload)"

# View Cloud Run logs
gcloud logging read "resource.type=cloud_run_revision" \
  --limit=50 \
  --format="table(timestamp,severity,textPayload)"

# View logs for a specific build
gcloud logging read "resource.type=build AND resource.labels.build_id=BUILD_ID" \
  --limit=100

# View logs from the centralized bucket
gcloud logging read "logName:projects/PROJECT_ID/locations/global/buckets/cloud-build-logs" \
  --limit=50
```

### Using Cloud Console

1. Navigate to **Cloud Console > Logging > Logs Explorer**
2. Use query filters:
   - Build logs: `resource.type="build"`
   - Cloud Run logs: `resource.type="cloud_run_revision"`
3. Adjust time range and severity as needed

### Log Query Examples

```bash
# Failed builds in the last hour
gcloud logging read "resource.type=build AND severity=ERROR AND timestamp>=\"$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)\""

# Deployment logs
gcloud logging read "resource.type=build AND textPayload:\"deploy\""

# Error logs from Cloud Run
gcloud logging read "resource.type=cloud_run_revision AND severity>=ERROR"
```

## Monitoring

### Monitoring Dashboard

A pre-configured dashboard provides visibility into:

1. **Build Success Rate**
   - Metric: `cloudbuild.googleapis.com/build/count`
   - Shows successful vs failed builds over time

2. **Build Duration**
   - Metric: `cloudbuild.googleapis.com/build/duration`
   - Average build time in seconds

3. **Cloud Run Request Count**
   - Metric: `run.googleapis.com/request_count`
   - Total requests to Cloud Run service

4. **Cloud Run Response Latency**
   - Metric: `run.googleapis.com/request_latencies`
   - Response time distribution

### Accessing the Dashboard

Get the dashboard URL from Terraform outputs:

```bash
cd terraform
terraform output monitoring_dashboard_url
```

Or navigate to:
```
https://console.cloud.google.com/monitoring/dashboards
```

### Alert Policies

Two alert policies are configured:

#### 1. Build Failure Alert

- **Trigger**: Any build fails
- **Condition**: Build failure rate > 0 for 60 seconds
- **Notification**: Email (if configured)
- **Auto-close**: 30 minutes after resolution

#### 2. Cloud Run Error Rate Alert

- **Trigger**: High 5xx error rate
- **Condition**: More than 5 errors per minute for 5 minutes
- **Notification**: Email (if configured)
- **Auto-close**: 30 minutes after resolution

### Configuring Email Notifications

Set the `alert_email` variable in `terraform/terraform.tfvars`:

```hcl
alert_email = "your-email@example.com"
```

Then apply the Terraform configuration:

```bash
cd terraform
terraform apply
```

## Metrics and KPIs

### Build Metrics

Monitor these key metrics:

| Metric | Description | Ideal Value |
|--------|-------------|-------------|
| Build Success Rate | Percentage of successful builds | > 95% |
| Build Duration | Average time to complete build | < 10 minutes |
| Build Frequency | Number of builds per day | Varies by team |
| Failed Build Recovery Time | Time to fix failed builds | < 1 hour |

### Application Metrics

| Metric | Description | Ideal Value |
|--------|-------------|-------------|
| Request Count | Requests per minute | Varies by traffic |
| Error Rate | 5xx errors per minute | < 1% |
| Response Latency | P50, P95, P99 latency | < 500ms P95 |
| Instance Count | Number of running instances | Depends on load |

### Viewing Metrics

```bash
# List available metrics
gcloud monitoring metrics-descriptors list \
  --filter="metric.type:cloudbuild"

# Get specific metric data
gcloud monitoring time-series list \
  --filter='metric.type="cloudbuild.googleapis.com/build/count"' \
  --interval-start-time="$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --interval-end-time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

## Custom Monitoring

### Creating Custom Metrics

Add custom metrics in your application:

```javascript
const { Monitoring } = require('@google-cloud/monitoring');
const client = new Monitoring.MetricServiceClient();

async function writeCustomMetric(value) {
  const projectId = process.env.GOOGLE_CLOUD_PROJECT;
  const projectName = client.projectPath(projectId);
  
  const dataPoint = {
    interval: {
      endTime: {
        seconds: Date.now() / 1000,
      },
    },
    value: {
      doubleValue: value,
    },
  };

  const timeSeries = {
    metric: {
      type: 'custom.googleapis.com/my_metric',
    },
    resource: {
      type: 'cloud_run_revision',
      labels: {
        project_id: projectId,
      },
    },
    points: [dataPoint],
  };

  await client.createTimeSeries({
    name: projectName,
    timeSeries: [timeSeries],
  });
}
```

### Creating Custom Alerts

Use Terraform to add custom alert policies:

```hcl
resource "google_monitoring_alert_policy" "custom_alert" {
  display_name = "Custom Alert"
  combiner     = "OR"
  
  conditions {
    display_name = "Custom metric threshold"
    
    condition_threshold {
      filter          = "metric.type=\"custom.googleapis.com/my_metric\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 100
      
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }
  
  notification_channels = [google_monitoring_notification_channel.email[0].id]
}
```

## Troubleshooting

### No Logs Appearing

1. Check if APIs are enabled:
   ```bash
   gcloud services list --enabled | grep logging
   ```

2. Verify log sink configuration:
   ```bash
   gcloud logging sinks list
   ```

3. Check IAM permissions:
   ```bash
   gcloud logging sinks describe cloud-build-logs-sink
   ```

### Alerts Not Firing

1. Verify notification channel:
   ```bash
   gcloud alpha monitoring channels list
   ```

2. Check alert policy:
   ```bash
   gcloud alpha monitoring policies list
   ```

3. Test the alert manually by triggering the condition

### Dashboard Not Showing Data

1. Wait a few minutes for data to propagate
2. Verify the project ID in the dashboard
3. Check if metrics are being collected:
   ```bash
   gcloud monitoring metrics-descriptors list
   ```

## Log Retention and Costs

### Retention Policies

- **Default retention**: 30 days
- **Maximum retention**: 3650 days (10 years)
- Configurable via `log_retention_days` variable

### Cost Optimization

1. **Adjust retention**: Lower retention for less critical logs
2. **Use log exclusions**: Exclude noisy logs
3. **Sample logs**: Use log sampling for high-volume logs

Example log exclusion:

```bash
gcloud logging sinks update cloud-build-logs-sink \
  --add-exclusion=name=exclude-debug,filter='severity<WARNING'
```

## Compliance and Audit

### Export Logs for Compliance

Export logs to Cloud Storage for long-term retention:

```bash
gcloud logging sinks create logs-to-gcs \
  storage.googleapis.com/BUCKET_NAME \
  --log-filter='resource.type="build"'
```

### Access Logs

All access to logs is tracked in Cloud Audit Logs:

```bash
gcloud logging read "protoPayload.serviceName=logging.googleapis.com" \
  --limit=50
```

## Additional Resources

- [Cloud Logging Documentation](https://cloud.google.com/logging/docs)
- [Cloud Monitoring Documentation](https://cloud.google.com/monitoring/docs)
- [Metrics Explorer](https://cloud.google.com/monitoring/charts/metrics-explorer)
- [Alert Policies](https://cloud.google.com/monitoring/alerts)

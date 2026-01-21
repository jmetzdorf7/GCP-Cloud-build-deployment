#!/bin/bash
# Deployment script for GCP Cloud Build CI/CD pipeline
# This script helps set up the infrastructure and configure Cloud Build

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    print_error "gcloud CLI is not installed. Please install it first."
    exit 1
fi

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed. Please install it first."
    exit 1
fi

print_info "Starting GCP Cloud Build CI/CD Pipeline setup..."

# Get project ID
if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID=$(gcloud config get-value project)
    if [ -z "$PROJECT_ID" ]; then
        print_error "PROJECT_ID is not set. Set it with: export PROJECT_ID=your-project-id"
        exit 1
    fi
fi

print_info "Using GCP Project: $PROJECT_ID"

# Enable required APIs
print_info "Enabling required GCP APIs..."
gcloud services enable cloudbuild.googleapis.com --project=$PROJECT_ID
gcloud services enable run.googleapis.com --project=$PROJECT_ID
gcloud services enable logging.googleapis.com --project=$PROJECT_ID
gcloud services enable monitoring.googleapis.com --project=$PROJECT_ID
gcloud services enable containerregistry.googleapis.com --project=$PROJECT_ID
gcloud services enable containerscanning.googleapis.com --project=$PROJECT_ID

print_info "APIs enabled successfully"

# Navigate to terraform directory
cd terraform

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    print_warn "terraform.tfvars not found. Creating from example..."
    cp terraform.tfvars.example terraform.tfvars
    sed -i "s/landingzone-cloud-build-primary/$PROJECT_ID/" terraform.tfvars
    print_info "Created terraform.tfvars. Please review and update as needed."
    print_info "You may want to set alert_email in terraform.tfvars"
fi

# Initialize Terraform
print_info "Initializing Terraform..."
terraform init

# Validate Terraform configuration
print_info "Validating Terraform configuration..."
terraform validate

# Show Terraform plan
print_info "Generating Terraform plan..."
terraform plan -out=tfplan

# Ask for confirmation
read -p "Do you want to apply this Terraform plan? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    print_warn "Deployment cancelled"
    exit 0
fi

# Apply Terraform configuration
print_info "Applying Terraform configuration..."
terraform apply tfplan

# Get outputs
print_info "Deployment complete! Here are the important outputs:"
echo ""
terraform output

# Return to root directory
cd ..

print_info "Setup complete!"
print_info "Next steps:"
echo "  1. Review the Terraform outputs above"
echo "  2. Set up Cloud Build trigger (see README.md for instructions)"
echo "  3. Test the pipeline with: gcloud builds submit --config=cloudbuild.yaml"
echo ""
print_info "For monitoring dashboard, run: cd terraform && terraform output monitoring_dashboard_url"

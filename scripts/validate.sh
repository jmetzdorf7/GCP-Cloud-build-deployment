#!/bin/bash
# Script to validate the Cloud Build pipeline configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_info "Validating Cloud Build configuration..."

# Check if cloudbuild.yaml exists
if [ ! -f "cloudbuild.yaml" ]; then
    print_error "cloudbuild.yaml not found in current directory"
    exit 1
fi

# Validate YAML syntax
if command -v yamllint &> /dev/null; then
    print_info "Checking YAML syntax..."
    yamllint cloudbuild.yaml || true
else
    print_info "yamllint not installed, skipping YAML syntax check"
fi

# Check if Dockerfile exists
if [ ! -f "Dockerfile" ]; then
    print_error "Dockerfile not found in current directory"
    exit 1
fi

print_success "Cloud Build configuration is valid"

# Validate Terraform configuration
print_info "Validating Terraform configuration..."
cd terraform

if ! terraform fmt -check; then
    print_error "Terraform files are not properly formatted. Run 'terraform fmt' to fix."
    exit 1
fi

if ! terraform validate; then
    print_error "Terraform validation failed"
    exit 1
fi

cd ..

print_success "Terraform configuration is valid"

print_success "All validations passed!"

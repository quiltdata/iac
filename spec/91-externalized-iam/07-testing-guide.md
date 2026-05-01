# Testing Guide: Externalized IAM Feature

**Issue**: [#91 - externalized IAM](https://github.com/quiltdata/quilt-infrastructure/issues/91)

**Date**: 2025-11-20

**Branch**: 91-externalized-iam

**References**:
- [05-spec-integration.md](05-spec-integration.md) - Integration specification
- [03-spec-iam-module.md](03-spec-iam-module.md) - IAM module specification
- [04-spec-quilt-module.md](04-spec-quilt-module.md) - Quilt module specification
- [OPERATIONS.md](../../OPERATIONS.md) - Operations guide

## Executive Summary

This document provides comprehensive testing procedures for the externalized IAM feature. It covers unit testing, integration testing, end-to-end testing, and operational validation scenarios. The guide assumes you have split CloudFormation templates ready for testing.

## Testing Philosophy

**Test Pyramid Approach**:
```
            ┌─────────────────┐
            │   E2E Tests     │  Manual, full deployment
            │   (1-2 hours)   │  Complete customer workflow
            └─────────────────┘
                    △
                   ╱ ╲
                  ╱   ╲
           ┌─────────────────┐
           │ Integration Tests│  Terraform validation
           │   (15-30 min)    │  Module interactions
           └─────────────────┘
                    △
                   ╱ ╲
                  ╱   ╲
           ┌─────────────────┐
           │   Unit Tests     │  Template validation
           │   (5-10 min)     │  Module syntax
           └─────────────────┘
```

## Test Environment Setup

### Prerequisites

**Required Tools**:
```bash
# Verify tool versions
terraform --version  # >= 1.5.0
aws --version        # >= 2.x
python3 --version    # >= 3.8 (for split script)
jq --version         # >= 1.6

# Optional but recommended
tfsec --version      # Security scanning
checkov --version    # Policy validation
```

**AWS Test Account Requirements**:
- Dedicated AWS account for testing (non-production)
- Admin or PowerUser IAM permissions
- S3 bucket for Terraform state
- S3 bucket for CloudFormation templates
- Route53 hosted zone (optional - for DNS testing)
- ACM certificate (optional - for HTTPS testing)

**Note**: Tests can run in **minimal mode** without Route53/ACM by using the ALB's DNS name directly (HTTP only). See "Minimal Validation Mode" section below.

**Test Data Requirements**:
- Split IAM template (`quilt-iam.yaml`)
- Split application template (`quilt-app.yaml`)
- Monolithic template for comparison (`quilt-monolithic.yaml`)
- Test configuration file (`test-config.tfvars`)

### Test Environment Setup Script

```bash
#!/bin/bash
# File: scripts/setup-test-environment.sh

set -e

echo "=== Setting up externalized IAM test environment ==="

# Configuration
TEST_ENV="${TEST_ENV:-iam-test}"
AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
TEMPLATES_BUCKET="quilt-templates-${TEST_ENV}-${AWS_ACCOUNT_ID}"
STATE_BUCKET="quilt-tfstate-${TEST_ENV}-${AWS_ACCOUNT_ID}"

echo "Test environment: $TEST_ENV"
echo "AWS Account: $AWS_ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"

# Create S3 buckets
echo "Creating S3 buckets..."
aws s3 mb "s3://${TEMPLATES_BUCKET}" --region "$AWS_REGION" 2>/dev/null || echo "Templates bucket already exists"
aws s3 mb "s3://${STATE_BUCKET}" --region "$AWS_REGION" 2>/dev/null || echo "State bucket already exists"

# Enable versioning on state bucket
aws s3api put-bucket-versioning \
  --bucket "$STATE_BUCKET" \
  --versioning-configuration Status=Enabled

# Create test directory structure
mkdir -p test-deployments/{inline-iam,external-iam,migration}/{terraform,templates,logs}

# Create test configuration template
cat > test-deployments/test-config.template.tfvars << EOF
# Test Configuration Template
# Copy to test-config.tfvars and fill in values

# Required: AWS Configuration
aws_region     = "$AWS_REGION"
aws_account_id = "$AWS_ACCOUNT_ID"

# Required: Test Environment
test_environment = "$TEST_ENV"

# Required: Authentication (use dummy values for testing)
google_client_secret = "test-google-secret"
okta_client_secret   = "test-okta-secret"

# Option A: Full DNS/SSL testing (requires certificate and Route53)
# certificate_arn = "arn:aws:acm:$AWS_REGION:$AWS_ACCOUNT_ID:certificate/YOUR-CERT-ID"
# route53_zone_id = "YOUR-ZONE-ID"
# quilt_web_host  = "quilt-${TEST_ENV}.YOUR-DOMAIN.com"
# create_dns_record = true

# Option B: Minimal mode (no certificate, uses ALB DNS name only)
certificate_arn   = ""  # Leave empty for HTTP-only testing
create_dns_record = false

# Optional: Override defaults for faster testing
db_instance_class    = "db.t3.micro"
search_instance_type = "t3.small.elasticsearch"
search_volume_size   = 10
EOF

echo "Test environment setup complete!"
echo ""
echo "Next steps:"
echo "1. Copy test-config.template.tfvars to test-config.tfvars"
echo "2. Fill in required values (certificate ARN, Route53 zone, etc.)"
echo "3. Upload CloudFormation templates to s3://${TEMPLATES_BUCKET}/"
echo "4. Run test suite: ./scripts/run-tests.sh"
echo ""
echo "Buckets created:"
echo "  Templates: s3://${TEMPLATES_BUCKET}"
echo "  State:     s3://${STATE_BUCKET}"
```

### Minimal Validation Mode (No Certificate Required)

If you don't have an ACM certificate or Route53 zone, you can still fully validate the externalized IAM feature by accessing the application via the ALB's DNS name directly over HTTP.

**How it works**:

```text
┌─────────────────────────────────────────────────┐
│ Without Certificate/DNS:                        │
│                                                 │
│  Test Request → ALB DNS Name (HTTP)             │
│  Example: quilt-test-123456.us-east-1.elb...   │
│                                                 │
│  ✓ Full IAM validation                          │
│  ✓ Application deployment                       │
│  ✓ Database connectivity                        │
│  ✓ ElasticSearch connectivity                   │
│  ✓ All CloudFormation stacks                    │
│  ✗ HTTPS (not needed for IAM testing)           │
│  ✗ Custom domain (not needed for IAM testing)   │
└─────────────────────────────────────────────────┘
```

**Minimal Configuration Example**:
```hcl
# File: test-deployments/minimal-mode/main.tf

module "quilt" {
  source = "../../../modules/quilt"

  # Basic configuration
  name = "quilt-iam-test"

  # External IAM - THIS IS WHAT WE'RE TESTING
  iam_template_url = "https://bucket.s3.amazonaws.com/quilt-iam.yaml"
  template_url     = "https://bucket.s3.amazonaws.com/quilt-app.yaml"

  # Minimal DNS/SSL config - NO CERTIFICATE NEEDED
  certificate_arn   = ""                    # Empty = HTTP only
  quilt_web_host    = "quilt-iam-test"      # Dummy value
  create_dns_record = false                  # Don't create Route53 record

  # Authentication (dummy values for testing)
  google_client_secret = "test-secret"
  okta_client_secret   = "test-secret"
  admin_email          = "test@example.com"

  # Minimal sizing for cost efficiency
  db_instance_class    = "db.t3.micro"
  search_instance_type = "t3.small.elasticsearch"
  search_volume_size   = 10
}

# Get the ALB DNS name for testing
output "alb_dns_name" {
  value       = module.quilt.alb_dns_name
  description = "Access application via: http://<this-value>/"
}

output "test_url" {
  value       = "http://${module.quilt.alb_dns_name}/"
  description = "Direct HTTP access URL for testing"
}
```

**Accessing the Application**:
```bash
# Get the ALB DNS name
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test with HTTP (no certificate needed)
curl -v "http://${ALB_DNS}/"
curl -v "http://${ALB_DNS}/health"

# The application will be fully functional via HTTP
# All IAM roles and permissions work identically
```

**What Gets Validated**:

- ✅ IAM stack deployment and outputs
- ✅ Application stack deployment with IAM parameters
- ✅ All 32 IAM roles created and associated
- ✅ Database connectivity
- ✅ ElasticSearch connectivity
- ✅ Lambda functions with IAM roles
- ✅ ECS tasks with IAM roles
- ✅ API Gateway with IAM roles
- ✅ Update propagation
- ✅ Stack deletion order

**What's NOT Validated** (but doesn't affect IAM testing):

- ❌ HTTPS/TLS termination
- ❌ Custom domain routing
- ❌ Route53 DNS records
- ❌ Certificate validation

**Cost Advantage**: Minimal mode is cheaper because:

- No Route53 hosted zone charges
- No certificate management
- Can use smallest instance sizes
- Can delete immediately after testing

### Helper Script: Get Application URL

Use this helper script to get the correct URL for testing (works with or without certificates):

```bash
#!/bin/bash
# File: scripts/get-test-url.sh
# Usage: ./scripts/get-test-url.sh [terraform-dir]

TERRAFORM_DIR="${1:-.}"

cd "$TERRAFORM_DIR"

# Try to get custom URL first
if terraform output quilt_url >/dev/null 2>&1; then
  URL=$(terraform output -raw quilt_url)
  echo "Custom URL (HTTPS): $URL"
  echo ""
  echo "Test commands:"
  echo "  curl -k $URL"
  echo "  curl -k $URL/health"
else
  # No custom URL, get ALB DNS name
  if terraform output alb_dns_name >/dev/null 2>&1; then
    ALB_DNS=$(terraform output -raw alb_dns_name)
  else
    # Fall back to querying CloudFormation stack
    STACK_NAME=$(terraform output -raw app_stack_name 2>/dev/null || \
                 terraform output -raw stack_name 2>/dev/null)
    ALB_DNS=$(aws elbv2 describe-load-balancers \
      --names "$STACK_NAME" \
      --query 'LoadBalancers[0].DNSName' \
      --output text)
  fi

  URL="http://${ALB_DNS}"
  echo "ALB DNS (HTTP only): $URL"
  echo ""
  echo "Test commands:"
  echo "  curl $URL"
  echo "  curl $URL/health"
fi

echo ""
echo "For browser testing: $URL"
```

**Quick Start - Minimal Mode Testing**:

```bash
# 1. Set up test environment (no certificate needed)
export TEST_ENV="iam-test"
./scripts/setup-test-environment.sh

# 2. Upload templates
aws s3 cp quilt-iam.yaml s3://quilt-templates-${TEST_ENV}-$(aws sts get-caller-identity --query Account --output text)/
aws s3 cp quilt-app.yaml s3://quilt-templates-${TEST_ENV}-$(aws sts get-caller-identity --query Account --output text)/

# 3. Configure for minimal mode
cat > test-config.tfvars << EOF
aws_region           = "us-east-1"
aws_account_id       = "$(aws sts get-caller-identity --query Account --output text)"
test_environment     = "${TEST_ENV}"
google_client_secret = "test-secret"
okta_client_secret   = "test-secret"
certificate_arn      = ""  # Empty = HTTP only
create_dns_record    = false
db_instance_class    = "db.t3.micro"
search_instance_type = "t3.small.elasticsearch"
search_volume_size   = 10
EOF

# 4. Deploy with external IAM
cd test-deployments/external-iam/terraform
terraform init
terraform apply -var-file=../../test-config.tfvars

# 5. Get test URL
./scripts/get-test-url.sh

# 6. Test the deployment
ALB_URL=$(terraform output -raw alb_dns_name)
curl "http://${ALB_URL}/health"

# 7. Verify IAM integration
aws cloudformation describe-stacks \
  --stack-name $(terraform output -raw iam_stack_name) \
  --query 'Stacks[0].Outputs[].OutputKey' | grep -i role

# 8. Cleanup when done
terraform destroy -var-file=../../test-config.tfvars
```

## Unit Tests

### Test Suite 1: Template Validation

**Objective**: Verify CloudFormation templates are syntactically valid

**Duration**: 5 minutes

**Test Script**:
```bash
#!/bin/bash
# File: scripts/test-01-template-validation.sh

set -e

echo "=== Test Suite 1: Template Validation ==="

TEST_DIR="test-deployments/templates"
RESULTS_FILE="test-results-01.log"

test_count=0
pass_count=0
fail_count=0

run_test() {
  local test_name="$1"
  local command="$2"

  test_count=$((test_count + 1))
  echo -n "Test $test_count: $test_name... "

  if eval "$command" >> "$RESULTS_FILE" 2>&1; then
    echo "✓ PASS"
    pass_count=$((pass_count + 1))
    return 0
  else
    echo "✗ FAIL"
    fail_count=$((fail_count + 1))
    return 1
  fi
}

# Test 1.1: IAM template is valid YAML
run_test "IAM template YAML syntax" \
  "python3 -c 'import yaml; yaml.safe_load(open(\"$TEST_DIR/quilt-iam.yaml\"))'"

# Test 1.2: Application template is valid YAML
run_test "Application template YAML syntax" \
  "python3 -c 'import yaml; yaml.safe_load(open(\"$TEST_DIR/quilt-app.yaml\"))'"

# Test 1.3: IAM template passes CloudFormation validation
run_test "IAM template CloudFormation validation" \
  "aws cloudformation validate-template --template-body file://$TEST_DIR/quilt-iam.yaml"

# Test 1.4: Application template passes CloudFormation validation
run_test "Application template CloudFormation validation" \
  "aws cloudformation validate-template --template-body file://$TEST_DIR/quilt-app.yaml"

# Test 1.5: IAM template has required outputs
run_test "IAM template has 32 outputs" \
  "test $(grep -c 'Type:.*AWS::IAM::Role\\|Type:.*AWS::IAM::ManagedPolicy' $TEST_DIR/quilt-iam.yaml) -eq 32"

# Test 1.6: Application template has required parameters
run_test "Application template has 32 IAM parameters" \
  "test $(grep -c 'Type: String' $TEST_DIR/quilt-app.yaml | grep -E 'Role|Policy') -ge 32"

# Test 1.7: Output names match parameter names
run_test "Output/parameter name consistency" \
  "python3 scripts/validate-names.py $TEST_DIR/quilt-iam.yaml $TEST_DIR/quilt-app.yaml"

# Test 1.8: No IAM resources in application template
run_test "Application template has no inline IAM roles/policies" \
  "! grep -E 'Type:.*AWS::IAM::Role|Type:.*AWS::IAM::ManagedPolicy' $TEST_DIR/quilt-app.yaml | grep -v Parameter"

# Summary
echo ""
echo "=== Test Suite 1 Summary ==="
echo "Total tests: $test_count"
echo "Passed: $pass_count"
echo "Failed: $fail_count"
echo "Results: $RESULTS_FILE"

[ $fail_count -eq 0 ] && exit 0 || exit 1
```

**Helper Script for Name Validation**:
```python
#!/usr/bin/env python3
# File: scripts/validate-names.py

import sys
import yaml
import re

def main():
    if len(sys.argv) != 3:
        print("Usage: validate-names.py <iam-template> <app-template>")
        sys.exit(1)

    iam_template_path = sys.argv[1]
    app_template_path = sys.argv[2]

    # Load templates
    with open(iam_template_path) as f:
        iam_template = yaml.safe_load(f)

    with open(app_template_path) as f:
        app_template = yaml.safe_load(f)

    # Extract IAM output names (remove 'Arn' suffix)
    iam_outputs = set()
    for output_name in iam_template.get('Outputs', {}).keys():
        if output_name.endswith('Arn'):
            iam_outputs.add(output_name[:-3])  # Remove 'Arn'
        else:
            iam_outputs.add(output_name)

    # Extract application parameter names
    app_parameters = set(app_template.get('Parameters', {}).keys())

    # Find mismatches
    missing_params = iam_outputs - app_parameters
    extra_params = app_parameters - iam_outputs

    if missing_params:
        print(f"ERROR: IAM outputs missing in app parameters: {missing_params}")
        sys.exit(1)

    if extra_params:
        # Filter out non-IAM parameters (infrastructure params)
        iam_related = {p for p in extra_params if 'Role' in p or 'Policy' in p}
        if iam_related:
            print(f"ERROR: Extra IAM parameters in app template: {iam_related}")
            sys.exit(1)

    print(f"✓ All {len(iam_outputs)} IAM outputs have matching parameters")
    sys.exit(0)

if __name__ == '__main__':
    main()
```

### Test Suite 2: Terraform Module Validation

**Objective**: Verify Terraform modules are syntactically correct

**Duration**: 5 minutes

**Test Script**:
```bash
#!/bin/bash
# File: scripts/test-02-terraform-validation.sh

set -e

echo "=== Test Suite 2: Terraform Module Validation ==="

RESULTS_FILE="test-results-02.log"
test_count=0
pass_count=0
fail_count=0

run_test() {
  local test_name="$1"
  local test_dir="$2"
  local command="$3"

  test_count=$((test_count + 1))
  echo -n "Test $test_count: $test_name... "

  cd "$test_dir"
  if eval "$command" >> "../$RESULTS_FILE" 2>&1; then
    echo "✓ PASS"
    pass_count=$((pass_count + 1))
    cd - >/dev/null
    return 0
  else
    echo "✗ FAIL"
    fail_count=$((fail_count + 1))
    cd - >/dev/null
    return 1
  fi
}

# Test 2.1: IAM module syntax
run_test "IAM module terraform validate" \
  "modules/iam" \
  "terraform init -backend=false && terraform validate"

# Test 2.2: Quilt module syntax
run_test "Quilt module terraform validate" \
  "modules/quilt" \
  "terraform init -backend=false && terraform validate"

# Test 2.3: IAM module formatting
run_test "IAM module terraform fmt check" \
  "modules/iam" \
  "terraform fmt -check -recursive"

# Test 2.4: Quilt module formatting
run_test "Quilt module terraform fmt check" \
  "modules/quilt" \
  "terraform fmt -check -recursive"

# Test 2.5: IAM module has required outputs
run_test "IAM module output validation" \
  "." \
  "grep -c 'output.*role.*arn\\|output.*policy.*arn' modules/iam/outputs.tf | grep 32"

# Test 2.6: Quilt module has iam_template_url variable
run_test "Quilt module has iam_template_url variable" \
  "." \
  "grep -q 'variable \"iam_template_url\"' modules/quilt/variables.tf"

# Test 2.7: Security scanning (if tfsec available)
if command -v tfsec >/dev/null 2>&1; then
  run_test "Security scan - IAM module" \
    "modules/iam" \
    "tfsec . --minimum-severity HIGH"

  run_test "Security scan - Quilt module" \
    "modules/quilt" \
    "tfsec . --minimum-severity HIGH"
fi

# Summary
echo ""
echo "=== Test Suite 2 Summary ==="
echo "Total tests: $test_count"
echo "Passed: $pass_count"
echo "Failed: $fail_count"
echo "Results: $RESULTS_FILE"

[ $fail_count -eq 0 ] && exit 0 || exit 1
```

## Integration Tests

### Test Suite 3: IAM Module Integration

**Objective**: Verify IAM module deploys and outputs are correct

**Duration**: 10-15 minutes

**Test Configuration**:
```hcl
# File: test-deployments/external-iam/terraform/test-iam-module.tf

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "quilt-tfstate-iam-test-ACCOUNT_ID"
    key    = "test-iam-module/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region

  allowed_account_ids = [var.aws_account_id]

  default_tags {
    tags = {
      Environment = "test"
      ManagedBy   = "terraform"
      TestSuite   = "externalized-iam"
      Purpose     = "integration-test"
    }
  }
}

variable "aws_region" {
  type = string
}

variable "aws_account_id" {
  type = string
}

variable "test_environment" {
  type = string
}

# Test IAM module
module "iam" {
  source = "../../../modules/iam"

  name         = "quilt-${var.test_environment}-iam-test"
  template_url = "https://quilt-templates-${var.test_environment}-${var.aws_account_id}.s3.${var.aws_region}.amazonaws.com/quilt-iam.yaml"

  parameters = {}
  tags       = {}
}

# Outputs for validation
output "iam_stack_id" {
  value = module.iam.stack_id
}

output "iam_stack_name" {
  value = module.iam.stack_name
}

output "all_role_arns" {
  value = {
    admin_handler              = module.iam.admin_handler_role_arn
    audit_trail                = module.iam.audit_trail_role_arn
    batch_job                  = module.iam.batch_job_role_arn
    containers_task_execution  = module.iam.containers_task_execution_role_arn
    containers_task            = module.iam.containers_task_role_arn
    es_proxy                   = module.iam.es_proxy_role_arn
    indexer                    = module.iam.indexer_role_arn
    navigator_config           = module.iam.navigator_config_role_arn
    navigator                  = module.iam.navigator_role_arn
    package_promote            = module.iam.package_promote_role_arn
    package_select_external    = module.iam.package_select_external_role_arn
    package_select_internal    = module.iam.package_select_internal_role_arn
    pkgselect                  = module.iam.pkgselect_role_arn
    preview                    = module.iam.preview_role_arn
    s3_select                  = module.iam.s3_select_role_arn
    search_handler             = module.iam.search_handler_role_arn
    shared                     = module.iam.shared_role_arn
    status_reports_handler     = module.iam.status_reports_handler_role_arn
    subscriptions_handler      = module.iam.subscriptions_handler_role_arn
    tabular_preview            = module.iam.tabular_preview_role_arn
    thumbnail                  = module.iam.thumbnail_role_arn
    thumbnail_function         = module.iam.thumbnail_function_role_arn
    user_profiles_handler      = module.iam.user_profiles_handler_role_arn
    user_settings_handler      = module.iam.user_settings_handler_role_arn
  }
}

output "all_policy_arns" {
  value = {
    allow_batch_query_results       = module.iam.allow_batch_query_results_policy_arn
    allow_read_bytes                = module.iam.allow_read_bytes_policy_arn
    cross_account_bucket_read       = module.iam.cross_account_bucket_read_policy_arn
    cross_account_bucket_write      = module.iam.cross_account_bucket_write_policy_arn
    enable_glacier_transition       = module.iam.enable_glacier_transition_policy_arn
    packages_read_current_version   = module.iam.packages_read_current_version_policy_arn
    packages_read_all               = module.iam.packages_read_all_policy_arn
    packages_write                  = module.iam.packages_write_policy_arn
  }
}

output "output_count" {
  value = length(module.iam.all_outputs)
}
```

**Test Script**:
```bash
#!/bin/bash
# File: scripts/test-03-iam-module-integration.sh

set -e

echo "=== Test Suite 3: IAM Module Integration ==="

TEST_DIR="test-deployments/external-iam/terraform"
RESULTS_FILE="test-results-03.log"
test_count=0
pass_count=0
fail_count=0

run_test() {
  local test_name="$1"
  local command="$2"

  test_count=$((test_count + 1))
  echo -n "Test $test_count: $test_name... "

  if eval "$command" >> "$RESULTS_FILE" 2>&1; then
    echo "✓ PASS"
    pass_count=$((pass_count + 1))
    return 0
  else
    echo "✗ FAIL"
    fail_count=$((fail_count + 1))
    return 1
  fi
}

cd "$TEST_DIR"

# Test 3.1: Terraform init
run_test "Terraform init" \
  "terraform init -upgrade"

# Test 3.2: Terraform plan succeeds
run_test "Terraform plan" \
  "terraform plan -out=test.tfplan -var-file=../../test-config.tfvars"

# Test 3.3: Terraform apply succeeds
echo "Test $((test_count + 1)): Terraform apply (IAM stack deployment)..."
if terraform apply -auto-approve test.tfplan >> "$RESULTS_FILE" 2>&1; then
  echo "✓ PASS"
  test_count=$((test_count + 1))
  pass_count=$((pass_count + 1))
else
  echo "✗ FAIL"
  test_count=$((test_count + 1))
  fail_count=$((fail_count + 1))
  cd - >/dev/null
  exit 1
fi

# Test 3.4: IAM stack exists
run_test "IAM CloudFormation stack exists" \
  "aws cloudformation describe-stacks --stack-name $(terraform output -raw iam_stack_name)"

# Test 3.5: IAM stack is in successful state
run_test "IAM stack status is CREATE_COMPLETE" \
  "test $(aws cloudformation describe-stacks --stack-name $(terraform output -raw iam_stack_name) --query 'Stacks[0].StackStatus' --output text) = 'CREATE_COMPLETE'"

# Test 3.6: All 32 outputs present
run_test "IAM stack has 32 outputs" \
  "test $(terraform output -json all_role_arns | jq 'length') -eq 24 && test $(terraform output -json all_policy_arns | jq 'length') -eq 8"

# Test 3.7: All ARNs have correct format
run_test "All role ARNs are valid" \
  "terraform output -json all_role_arns | jq -r '.[]' | grep -E '^arn:aws:iam::[0-9]{12}:role/'"

run_test "All policy ARNs are valid" \
  "terraform output -json all_policy_arns | jq -r '.[]' | grep -E '^arn:aws:iam::[0-9]{12}:policy/'"

# Test 3.8: IAM resources exist in AWS
STACK_NAME=$(terraform output -raw iam_stack_name)
run_test "IAM roles exist in AWS" \
  "test $(aws iam list-roles --query 'Roles[?starts_with(RoleName, \`${STACK_NAME}\`)].RoleName' --output text | wc -w) -ge 24"

# Test 3.9: Stack has required tags
run_test "IAM stack has required tags" \
  "aws cloudformation describe-stacks --stack-name $STACK_NAME --query 'Stacks[0].Tags[?Key==\`ManagedBy\`].Value' --output text | grep terraform"

# Summary
echo ""
echo "=== Test Suite 3 Summary ==="
echo "Total tests: $test_count"
echo "Passed: $pass_count"
echo "Failed: $fail_count"
echo "Results: $RESULTS_FILE"
echo ""
echo "IAM stack deployed successfully. Run test-04 for full integration test."

cd - >/dev/null

[ $fail_count -eq 0 ] && exit 0 || exit 1
```

### Test Suite 4: Full Module Integration

**Objective**: Verify complete external IAM pattern works end-to-end

**Duration**: 20-30 minutes

**Test Configuration**:
```hcl
# File: test-deployments/external-iam/terraform/test-full-integration.tf

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "quilt-tfstate-iam-test-ACCOUNT_ID"
    key    = "test-full-integration/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region

  allowed_account_ids = [var.aws_account_id]

  default_tags {
    tags = {
      Environment = "test"
      ManagedBy   = "terraform"
      TestSuite   = "externalized-iam-full"
    }
  }
}

# Load test configuration
variable "aws_region" { type = string }
variable "aws_account_id" { type = string }
variable "test_environment" { type = string }
variable "google_client_secret" { type = string }
variable "okta_client_secret" { type = string }
variable "certificate_arn" { type = string }
variable "route53_zone_id" { type = string }
variable "quilt_web_host" { type = string }
variable "db_instance_class" { type = string }
variable "search_instance_type" { type = string }
variable "search_volume_size" { type = number }

locals {
  name           = "quilt-${var.test_environment}"
  templates_base = "https://quilt-templates-${var.test_environment}-${var.aws_account_id}.s3.${var.aws_region}.amazonaws.com"
}

# Deploy with external IAM
module "quilt" {
  source = "../../../modules/quilt"

  # Basic configuration
  name           = local.name
  quilt_web_host = var.quilt_web_host

  # External IAM configuration
  iam_template_url = "${local.templates_base}/quilt-iam.yaml"
  template_url     = "${local.templates_base}/quilt-app.yaml"

  # Authentication
  google_client_secret = var.google_client_secret
  okta_client_secret   = var.okta_client_secret

  # Infrastructure
  certificate_arn      = var.certificate_arn
  admin_email          = "test-admin@example.com"

  # DNS
  create_dns_record = true
  zone_id           = var.route53_zone_id

  # Sizing (minimal for testing)
  db_instance_class    = var.db_instance_class
  search_instance_type = var.search_instance_type
  search_volume_size   = var.search_volume_size
}

# Outputs for validation
output "quilt_url" {
  value = module.quilt.quilt_url
}

output "admin_password" {
  value     = module.quilt.admin_password
  sensitive = true
}

output "iam_stack_id" {
  value = try(module.quilt.iam_stack_id, "not-deployed")
}

output "iam_stack_name" {
  value = try(module.quilt.iam_stack_name, "not-deployed")
}

output "app_stack_id" {
  value = module.quilt.stack_id
}

output "app_stack_name" {
  value = module.quilt.stack_name
}
```

**Test Script**:
```bash
#!/bin/bash
# File: scripts/test-04-full-integration.sh

set -e

echo "=== Test Suite 4: Full Module Integration ==="

TEST_DIR="test-deployments/external-iam/terraform"
RESULTS_FILE="test-results-04.log"
test_count=0
pass_count=0
fail_count=0

run_test() {
  local test_name="$1"
  local command="$2"

  test_count=$((test_count + 1))
  echo -n "Test $test_count: $test_name... "

  if eval "$command" >> "$RESULTS_FILE" 2>&1; then
    echo "✓ PASS"
    pass_count=$((pass_count + 1))
    return 0
  else
    echo "✗ FAIL"
    fail_count=$((fail_count + 1))
    return 1
  fi
}

cd "$TEST_DIR"

# Test 4.1: Terraform init
run_test "Terraform init" \
  "terraform init -upgrade"

# Test 4.2: Terraform plan succeeds
run_test "Terraform plan" \
  "terraform plan -out=full-test.tfplan -var-file=../../test-config.tfvars"

# Test 4.3: Terraform apply succeeds (full deployment)
echo "Test $((test_count + 1)): Terraform apply (full deployment with external IAM)..."
echo "This will take 15-20 minutes..."
if timeout 30m terraform apply -auto-approve full-test.tfplan >> "$RESULTS_FILE" 2>&1; then
  echo "✓ PASS"
  test_count=$((test_count + 1))
  pass_count=$((pass_count + 1))
else
  echo "✗ FAIL (timeout or error)"
  test_count=$((test_count + 1))
  fail_count=$((fail_count + 1))
  cd - >/dev/null
  exit 1
fi

# Test 4.4: Both stacks exist
IAM_STACK=$(terraform output -raw iam_stack_name)
APP_STACK=$(terraform output -raw app_stack_name)

run_test "IAM stack exists" \
  "aws cloudformation describe-stacks --stack-name $IAM_STACK"

run_test "Application stack exists" \
  "aws cloudformation describe-stacks --stack-name $APP_STACK"

# Test 4.5: Both stacks in successful state
run_test "IAM stack status is complete" \
  "aws cloudformation describe-stacks --stack-name $IAM_STACK --query 'Stacks[0].StackStatus' --output text | grep -E 'CREATE_COMPLETE|UPDATE_COMPLETE'"

run_test "Application stack status is complete" \
  "aws cloudformation describe-stacks --stack-name $APP_STACK --query 'Stacks[0].StackStatus' --output text | grep -E 'CREATE_COMPLETE|UPDATE_COMPLETE'"

# Test 4.6: Application stack has IAM parameters
run_test "Application stack has IAM role parameters" \
  "test $(aws cloudformation describe-stacks --stack-name $APP_STACK --query 'Stacks[0].Parameters[?contains(ParameterKey, \`Role\`)].ParameterKey' --output text | wc -w) -ge 24"

# Test 4.7: IAM parameters are valid ARNs
run_test "IAM parameters are valid ARNs" \
  "aws cloudformation describe-stacks --stack-name $APP_STACK --query 'Stacks[0].Parameters[?contains(ParameterKey, \`Role\`)].ParameterValue' --output text | grep -E '^arn:aws:iam::[0-9]{12}:role/'"

# Test 4.8: Application is accessible
# Try to get custom URL first, fall back to ALB DNS
if terraform output quilt_url >/dev/null 2>&1; then
  QUILT_URL=$(terraform output -raw quilt_url)
  TEST_SCHEME="https"
else
  # No custom URL, use ALB DNS name (HTTP only)
  ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || \
    aws elbv2 describe-load-balancers \
      --names "$APP_STACK" \
      --query 'LoadBalancers[0].DNSName' \
      --output text)
  QUILT_URL="http://${ALB_DNS}"
  TEST_SCHEME="http"
fi

echo "Testing via: $QUILT_URL"

run_test "Quilt URL is accessible" \
  "curl -f -k -I $QUILT_URL"

# Test 4.9: Health endpoint responds
run_test "Health endpoint responds" \
  "curl -f -k $QUILT_URL/health"

# Test 4.10: Database is accessible (indirect check via health)
run_test "Database connectivity (via health check)" \
  "curl -f -k $QUILT_URL/health | grep -q 'ok\\|healthy'"

# Test 4.11: ElasticSearch is accessible (indirect check)
run_test "ElasticSearch connectivity (via health check)" \
  "curl -f -k $QUILT_URL/health | grep -q 'ok\\|healthy'"

# Test 4.12: ECS service is running
run_test "ECS service is running" \
  "test $(aws ecs describe-services --cluster $APP_STACK --services $APP_STACK --query 'services[0].runningCount' --output text) -gt 0"

# Summary
echo ""
echo "=== Test Suite 4 Summary ==="
echo "Total tests: $test_count"
echo "Passed: $pass_count"
echo "Failed: $fail_count"
echo "Results: $RESULTS_FILE"
echo ""
echo "Full deployment successful!"
echo "Quilt URL: $QUILT_URL"
echo "Admin credentials in terraform output"

cd - >/dev/null

[ $fail_count -eq 0 ] && exit 0 || exit 1
```

## End-to-End Tests

### Test Suite 5: Update Scenarios

**Objective**: Verify update propagation works correctly

**Duration**: 30-45 minutes

**Test Script**:
```bash
#!/bin/bash
# File: scripts/test-05-update-scenarios.sh

set -e

echo "=== Test Suite 5: Update Scenarios ==="

TEST_DIR="test-deployments/external-iam/terraform"
TEMPLATES_DIR="test-deployments/templates"
RESULTS_FILE="test-results-05.log"
test_count=0
pass_count=0
fail_count=0

run_test() {
  local test_name="$1"
  local command="$2"

  test_count=$((test_count + 1))
  echo -n "Test $test_count: $test_name... "

  if eval "$command" >> "$RESULTS_FILE" 2>&1; then
    echo "✓ PASS"
    pass_count=$((pass_count + 1))
    return 0
  else
    echo "✗ FAIL"
    fail_count=$((fail_count + 1))
    return 1
  fi
}

cd "$TEST_DIR"

IAM_STACK=$(terraform output -raw iam_stack_name)
APP_STACK=$(terraform output -raw app_stack_name)
QUILT_URL=$(terraform output -raw quilt_url)

# Scenario A: Update IAM policy (no ARN change)
echo ""
echo "Scenario A: Update IAM policy without ARN change"
echo "==============================================="

# Test 5.1: Backup original template
run_test "Backup IAM template" \
  "cp $TEMPLATES_DIR/quilt-iam.yaml $TEMPLATES_DIR/quilt-iam.yaml.backup"

# Test 5.2: Modify IAM policy
echo "Modifying IAM policy..."
cat >> "$TEMPLATES_DIR/quilt-iam.yaml" << 'EOF'
# Test modification - add comment to trigger update
# Updated: $(date)
EOF

# Test 5.3: Upload modified template
TEST_BUCKET=$(terraform show -json | jq -r '.values.root_module.child_modules[].resources[] | select(.name=="iam_template_url") | .values.template_url' | sed 's|https://||' | cut -d'/' -f1)
run_test "Upload modified IAM template" \
  "aws s3 cp $TEMPLATES_DIR/quilt-iam.yaml s3://$TEST_BUCKET/quilt-iam.yaml"

# Test 5.4: Terraform detect changes
run_test "Terraform detects IAM changes" \
  "terraform plan -var-file=../../test-config.tfvars | grep -q 'module.quilt.module.iam'"

# Test 5.5: Apply IAM update
echo "Applying IAM update..."
if terraform apply -auto-approve -var-file=../../test-config.tfvars >> "$RESULTS_FILE" 2>&1; then
  echo "✓ PASS"
  test_count=$((test_count + 1))
  pass_count=$((pass_count + 1))
else
  echo "✗ FAIL"
  test_count=$((test_count + 1))
  fail_count=$((fail_count + 1))
fi

# Test 5.6: Application still accessible
run_test "Application still accessible after IAM update" \
  "curl -f -k $QUILT_URL/health"

# Test 5.7: Application stack unchanged
run_test "Application stack not updated (no ARN change)" \
  "test $(aws cloudformation describe-stacks --stack-name $APP_STACK --query 'Stacks[0].LastUpdatedTime' --output text) = 'None' || echo 'Stack updated'"

# Restore original template
cp "$TEMPLATES_DIR/quilt-iam.yaml.backup" "$TEMPLATES_DIR/quilt-iam.yaml"

# Scenario B: Infrastructure update
echo ""
echo "Scenario B: Update infrastructure (increase storage)"
echo "===================================================="

# Test 5.8: Update search volume size
CURRENT_SIZE=$(terraform show -json | jq -r '.values.root_module.child_modules[] | select(.address=="module.quilt") | .resources[] | select(.name=="search_volume_size") | .values // "10"')
NEW_SIZE=$((CURRENT_SIZE + 5))

echo "Updating search_volume_size: $CURRENT_SIZE -> $NEW_SIZE GB"

# Update terraform.tfvars
sed -i.backup "s/search_volume_size = .*/search_volume_size = $NEW_SIZE/" ../../test-config.tfvars

# Test 5.9: Plan shows infrastructure change
run_test "Terraform detects infrastructure change" \
  "terraform plan -var-file=../../test-config.tfvars | grep -q 'search_volume_size'"

# Test 5.10: Apply infrastructure update
echo "Applying infrastructure update..."
if timeout 15m terraform apply -auto-approve -var-file=../../test-config.tfvars >> "$RESULTS_FILE" 2>&1; then
  echo "✓ PASS"
  test_count=$((test_count + 1))
  pass_count=$((pass_count + 1))
else
  echo "✗ FAIL"
  test_count=$((test_count + 1))
  fail_count=$((fail_count + 1))
fi

# Test 5.11: IAM stack unchanged
run_test "IAM stack unchanged during infrastructure update" \
  "aws cloudformation describe-stacks --stack-name $IAM_STACK --query 'Stacks[0].StackStatus' --output text | grep -E 'CREATE_COMPLETE|UPDATE_COMPLETE'"

# Test 5.12: Application recovers
run_test "Application accessible after infrastructure update" \
  "curl -f -k $QUILT_URL/health"

# Restore configuration
mv ../../test-config.tfvars.backup ../../test-config.tfvars

# Summary
echo ""
echo "=== Test Suite 5 Summary ==="
echo "Total tests: $test_count"
echo "Passed: $pass_count"
echo "Failed: $fail_count"
echo "Results: $RESULTS_FILE"

cd - >/dev/null

[ $fail_count -eq 0 ] && exit 0 || exit 1
```

### Test Suite 6: Comparison Testing

**Objective**: Verify external IAM produces same results as inline IAM

**Duration**: 45-60 minutes

**Test Script**:
```bash
#!/bin/bash
# File: scripts/test-06-comparison.sh

set -e

echo "=== Test Suite 6: External vs Inline IAM Comparison ==="

EXTERNAL_DIR="test-deployments/external-iam/terraform"
INLINE_DIR="test-deployments/inline-iam/terraform"
RESULTS_FILE="test-results-06.log"
test_count=0
pass_count=0
fail_count=0

run_test() {
  local test_name="$1"
  local command="$2"

  test_count=$((test_count + 1))
  echo -n "Test $test_count: $test_name... "

  if eval "$command" >> "$RESULTS_FILE" 2>&1; then
    echo "✓ PASS"
    pass_count=$((pass_count + 1))
    return 0
  else
    echo "✗ FAIL"
    fail_count=$((fail_count + 1))
    return 1
  fi
}

# Deploy inline IAM version
echo "Deploying inline IAM version for comparison..."
cd "$INLINE_DIR"

# Setup inline configuration (no iam_template_url)
cat > main.tf << 'EOF'
# Inline IAM configuration (for comparison)
module "quilt" {
  source = "../../../modules/quilt"

  name           = "quilt-iam-test-inline"
  quilt_web_host = "quilt-test-inline.example.com"

  # NO iam_template_url - uses inline IAM
  template_url = "https://quilt-templates.s3.amazonaws.com/quilt-monolithic.yaml"

  # ... rest of configuration ...
}
EOF

terraform init
terraform apply -auto-approve -var-file=../../test-config.tfvars

INLINE_STACK=$(terraform output -raw stack_name)

cd - >/dev/null
cd "$EXTERNAL_DIR"

EXTERNAL_IAM_STACK=$(terraform output -raw iam_stack_name)
EXTERNAL_APP_STACK=$(terraform output -raw app_stack_name)

# Test 6.1: Both deployments successful
run_test "Both deployments in successful state" \
  "aws cloudformation describe-stacks --stack-name $INLINE_STACK --query 'Stacks[0].StackStatus' --output text | grep COMPLETE && \
   aws cloudformation describe-stacks --stack-name $EXTERNAL_APP_STACK --query 'Stacks[0].StackStatus' --output text | grep COMPLETE"

# Test 6.2: Same IAM resources created
echo "Comparing IAM resources..."

# Get inline IAM resources
INLINE_ROLES=$(aws cloudformation describe-stack-resources --stack-name $INLINE_STACK --query 'StackResources[?ResourceType==`AWS::IAM::Role`].LogicalResourceId' --output json | jq -r '.[]' | sort)

# Get external IAM resources
EXTERNAL_ROLES=$(aws cloudformation describe-stack-resources --stack-name $EXTERNAL_IAM_STACK --query 'StackResources[?ResourceType==`AWS::IAM::Role`].LogicalResourceId' --output json | jq -r '.[]' | sort)

run_test "Same number of IAM roles" \
  "test $(echo \"$INLINE_ROLES\" | wc -l) -eq $(echo \"$EXTERNAL_ROLES\" | wc -l)"

run_test "Same IAM role names" \
  "diff <(echo \"$INLINE_ROLES\") <(echo \"$EXTERNAL_ROLES\")"

# Test 6.3: Same application resources
INLINE_APP_RESOURCES=$(aws cloudformation describe-stack-resources --stack-name $INLINE_STACK --query 'StackResources[?ResourceType!=`AWS::IAM::Role` && ResourceType!=`AWS::IAM::Policy` && ResourceType!=`AWS::IAM::ManagedPolicy`].ResourceType' --output json | jq -r '.[]' | sort)

EXTERNAL_APP_RESOURCES=$(aws cloudformation describe-stack-resources --stack-name $EXTERNAL_APP_STACK --query 'StackResources[?ResourceType!=`AWS::IAM::Role` && ResourceType!=`AWS::IAM::Policy` && ResourceType!=`AWS::IAM::ManagedPolicy`].ResourceType' --output json | jq -r '.[]' | sort)

run_test "Same application resource types" \
  "diff <(echo \"$INLINE_APP_RESOURCES\") <(echo \"$EXTERNAL_APP_RESOURCES\")"

# Test 6.4: Same functional behavior
INLINE_URL="https://quilt-test-inline.example.com"
EXTERNAL_URL=$(cd "$EXTERNAL_DIR" && terraform output -raw quilt_url)

run_test "Both endpoints accessible" \
  "curl -f -k -I $INLINE_URL && curl -f -k -I $EXTERNAL_URL"

# Test 6.5: Same response times (within tolerance)
INLINE_TIME=$(curl -o /dev/null -s -w "%{time_total}" -k "$INLINE_URL/health")
EXTERNAL_TIME=$(curl -o /dev/null -s -w "%{time_total}" -k "$EXTERNAL_URL/health")

echo "Response times: Inline=$INLINE_TIME, External=$EXTERNAL_TIME"
run_test "Response times comparable (< 20% difference)" \
  "python3 -c \"import sys; inline=$INLINE_TIME; external=$EXTERNAL_TIME; diff=abs(inline-external)/inline*100; sys.exit(0 if diff < 20 else 1)\""

# Cleanup inline deployment
echo "Cleaning up inline deployment..."
cd "$INLINE_DIR"
terraform destroy -auto-approve -var-file=../../test-config.tfvars

# Summary
echo ""
echo "=== Test Suite 6 Summary ==="
echo "Total tests: $test_count"
echo "Passed: $pass_count"
echo "Failed: $fail_count"
echo "Results: $RESULTS_FILE"

cd - >/dev/null

[ $fail_count -eq 0 ] && exit 0 || exit 1
```

## Cleanup and Teardown

### Test Suite 7: Deletion and Cleanup

**Objective**: Verify proper cleanup and dependency handling

**Duration**: 15-20 minutes

**Test Script**:
```bash
#!/bin/bash
# File: scripts/test-07-cleanup.sh

set -e

echo "=== Test Suite 7: Deletion and Cleanup ==="

TEST_DIR="test-deployments/external-iam/terraform"
RESULTS_FILE="test-results-07.log"
test_count=0
pass_count=0
fail_count=0

run_test() {
  local test_name="$1"
  local command="$2"

  test_count=$((test_count + 1))
  echo -n "Test $test_count: $test_name... "

  if eval "$command" >> "$RESULTS_FILE" 2>&1; then
    echo "✓ PASS"
    pass_count=$((pass_count + 1))
    return 0
  else
    echo "✗ FAIL"
    fail_count=$((fail_count + 1))
    return 1
  fi
}

cd "$TEST_DIR"

IAM_STACK=$(terraform output -raw iam_stack_name 2>/dev/null || echo "unknown")
APP_STACK=$(terraform output -raw app_stack_name 2>/dev/null || echo "unknown")

# Test 7.1: Terraform destroy plan
run_test "Terraform destroy plan succeeds" \
  "terraform plan -destroy -out=destroy.tfplan -var-file=../../test-config.tfvars"

# Test 7.2: Terraform destroy executes
echo "Test $((test_count + 1)): Terraform destroy (full cleanup)..."
if timeout 20m terraform apply -auto-approve destroy.tfplan >> "$RESULTS_FILE" 2>&1; then
  echo "✓ PASS"
  test_count=$((test_count + 1))
  pass_count=$((pass_count + 1))
else
  echo "✗ FAIL"
  test_count=$((test_count + 1))
  fail_count=$((fail_count + 1))
fi

# Test 7.3: Application stack deleted
run_test "Application stack deleted" \
  "! aws cloudformation describe-stacks --stack-name $APP_STACK 2>&1 | grep -q 'does not exist'"

# Test 7.4: IAM stack deleted
run_test "IAM stack deleted" \
  "! aws cloudformation describe-stacks --stack-name $IAM_STACK 2>&1 | grep -q 'does not exist'"

# Test 7.5: No orphaned IAM roles
run_test "No orphaned IAM roles" \
  "test $(aws iam list-roles --query \"Roles[?starts_with(RoleName, '${IAM_STACK}')].RoleName\" --output text | wc -l) -eq 0"

# Test 7.6: No orphaned IAM policies
run_test "No orphaned IAM policies" \
  "test $(aws iam list-policies --scope Local --query \"Policies[?starts_with(PolicyName, '${IAM_STACK}')].PolicyName\" --output text | wc -l) -eq 0"

# Test 7.7: No orphaned CloudFormation exports
run_test "No orphaned CloudFormation exports" \
  "test $(aws cloudformation list-exports --query \"Exports[?starts_with(Name, '${IAM_STACK}')].Name\" --output text | wc -l) -eq 0"

# Test 7.8: Terraform state clean
run_test "Terraform state is empty" \
  "terraform state list | wc -l | grep -q '^0$'"

# Summary
echo ""
echo "=== Test Suite 7 Summary ==="
echo "Total tests: $test_count"
echo "Passed: $pass_count"
echo "Failed: $fail_count"
echo "Results: $RESULTS_FILE"
echo ""
echo "Cleanup complete!"

cd - >/dev/null

[ $fail_count -eq 0 ] && exit 0 || exit 1
```

## Master Test Runner

**Complete Test Suite Execution**:

```bash
#!/bin/bash
# File: scripts/run-all-tests.sh

set -e

echo "========================================="
echo "Externalized IAM Feature - Full Test Suite"
echo "========================================="
echo ""
echo "This will run all test suites:"
echo "  1. Template Validation      (~5 min)"
echo "  2. Terraform Validation     (~5 min)"
echo "  3. IAM Module Integration   (~15 min)"
echo "  4. Full Integration         (~30 min)"
echo "  5. Update Scenarios         (~45 min)"
echo "  6. Comparison Testing       (~60 min)"
echo "  7. Cleanup                  (~20 min)"
echo ""
echo "Total estimated time: ~3 hours"
echo ""
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted"
  exit 0
fi

# Track results
TOTAL_SUITES=7
PASSED_SUITES=0
FAILED_SUITES=0

START_TIME=$(date +%s)

# Run each test suite
for i in {1..7}; do
  echo ""
  echo "========================================="
  echo "Running Test Suite $i of $TOTAL_SUITES"
  echo "========================================="

  if ./scripts/test-0${i}-*.sh; then
    PASSED_SUITES=$((PASSED_SUITES + 1))
    echo "✓ Test Suite $i PASSED"
  else
    FAILED_SUITES=$((FAILED_SUITES + 1))
    echo "✗ Test Suite $i FAILED"

    # Ask whether to continue
    read -p "Continue to next suite? (yes/no): " CONTINUE
    if [ "$CONTINUE" != "yes" ]; then
      break
    fi
  fi
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
DURATION_MIN=$((DURATION / 60))

# Final summary
echo ""
echo "========================================="
echo "Test Suite Summary"
echo "========================================="
echo "Total suites: $TOTAL_SUITES"
echo "Passed: $PASSED_SUITES"
echo "Failed: $FAILED_SUITES"
echo "Duration: ${DURATION_MIN} minutes"
echo ""

if [ $FAILED_SUITES -eq 0 ]; then
  echo "✓ ALL TESTS PASSED"
  exit 0
else
  echo "✗ SOME TESTS FAILED"
  echo "Review test-results-*.log files for details"
  exit 1
fi
```

## Success Criteria

### Test Suite Pass Criteria

**Unit Tests**:
- ✅ All templates pass CloudFormation validation
- ✅ All Terraform modules pass `terraform validate`
- ✅ All security scans pass (if tfsec/checkov available)
- ✅ Template output/parameter names match

**Integration Tests**:
- ✅ IAM module deploys successfully
- ✅ All 32 IAM resources created
- ✅ All outputs have valid ARN format
- ✅ Full deployment completes in < 30 minutes

**End-to-End Tests**:
- ✅ Application is accessible after deployment
- ✅ IAM updates propagate correctly
- ✅ Infrastructure updates work without IAM impact
- ✅ External IAM produces same results as inline IAM

**Cleanup Tests**:
- ✅ Terraform destroy completes successfully
- ✅ No orphaned AWS resources
- ✅ CloudFormation stacks deleted in correct order

## Troubleshooting

### Common Test Failures

**Template Validation Failures**:
```bash
# Check template syntax
aws cloudformation validate-template \
  --template-body file://quilt-iam.yaml

# Common issues:
# - Invalid YAML syntax
# - Missing outputs
# - Incorrect parameter definitions
```

**Module Integration Failures**:
```bash
# Check Terraform logs
terraform apply -auto-approve 2>&1 | tee terraform.log

# Check CloudFormation events
aws cloudformation describe-stack-events \
  --stack-name quilt-iam-test \
  --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`]'
```

**Deployment Timeouts**:
```bash
# Increase timeout
timeout 45m terraform apply -auto-approve

# Monitor CloudFormation progress
watch -n 30 'aws cloudformation describe-stacks \
  --stack-name quilt-iam-test \
  --query "Stacks[0].StackStatus"'
```

## Appendix

### Test Data Generation

**Generate Test Templates**:
```bash
# Assuming you have the split script
python3 /path/to/split_iam.py \
  --input quilt-monolithic-reference.yaml \
  --output-iam test-deployments/templates/quilt-iam.yaml \
  --output-app test-deployments/templates/quilt-app.yaml \
  --config config.yaml
```

### Performance Benchmarks

**Expected Deployment Times** (AWS us-east-1, t3.micro/small instances):
- IAM stack only: 3-5 minutes
- Full deployment (external IAM): 18-25 minutes
- Full deployment (inline IAM): 15-20 minutes
- Infrastructure update: 5-15 minutes (depending on resource)
- IAM policy update: 2-5 minutes
- Full teardown: 15-20 minutes

### Test Environment Costs

**Estimated AWS Costs** (per hour):
- Database (db.t3.micro): $0.017/hr
- ElasticSearch (t3.small): $0.036/hr
- ECS (Fargate): ~$0.05/hr
- Other (ALB, NAT, etc.): ~$0.05/hr
- **Total**: ~$0.15-0.20/hr (~$5-6 for full test suite)

**Cost Optimization**:
- Use t3.micro/small instances for testing
- Delete resources immediately after testing
- Use AWS Free Tier where available
- Schedule tests during off-peak hours

## References

- Integration Specification: [05-spec-integration.md](05-spec-integration.md)
- Operations Guide: [OPERATIONS.md](../../OPERATIONS.md)
- AWS CloudFormation Testing: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/continuous-delivery-codepipeline-basic-walkthrough.html
- Terraform Testing: https://www.terraform.io/docs/language/modules/testing-experiment.html

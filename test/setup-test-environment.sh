#!/bin/bash
# File: test/setup-test-environment.sh
# Test environment setup for externalized IAM feature testing

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

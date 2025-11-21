# Externalized IAM Testing Suite

Comprehensive test suite for validating the externalized IAM feature ([#91](https://github.com/quiltdata/quilt-infrastructure/issues/91)) that separates IAM resources into a standalone CloudFormation stack.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Test Structure](#test-structure)
- [Running Tests](#running-tests)
- [Testing Modes](#testing-modes)
- [Troubleshooting](#troubleshooting)
- [Cost Estimates](#cost-estimates)

## Overview

### What This Test Suite Does

This test suite validates the externalized IAM architecture, which splits Quilt's monolithic CloudFormation template into two independent stacks:

1. **IAM Stack** (`stable-iam.yaml`) - Contains all 31+ IAM roles and policies
2. **Application Stack** (`stable-app.yaml`) - Contains infrastructure resources with parameterized IAM

**Key Validations**:

- CloudFormation template syntax and structure
- IAM resource separation (no inline IAM in application stack)
- Output/parameter consistency between stacks
- Template deployability and integration
- Update propagation and stack dependencies
- Functional equivalence to monolithic template

### Why This Matters

Externalizing IAM provides critical benefits:

- **Security Compliance**: Separate IAM from infrastructure for better governance
- **Faster Updates**: Infrastructure changes don't require IAM re-provisioning
- **Role Reusability**: IAM roles can be shared across multiple Quilt deployments
- **Reduced Deployment Risk**: IAM changes are isolated from application updates
- **Better Testing**: IAM and infrastructure can be tested independently

## Quick Start

### Minimal Mode Testing (No Certificate Required)

You can fully validate the externalized IAM feature **without an ACM certificate or Route53 zone** by using the ALB's DNS name directly over HTTP. This is the fastest way to test.

**What Gets Validated**:

- ✅ IAM stack deployment and outputs
- ✅ Application stack deployment with IAM parameters
- ✅ All 31+ IAM roles created and associated
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

### Run Template Validation Tests (5 minutes)

Start with unit tests to verify template structure:

```bash
# Navigate to test directory
cd /Users/ernest/GitHub/iac/test

# Run template validation (Test Suite 1)
./run_validation.sh
```

**Expected Output**:

```text
=== Test Suite 1: Template Validation ===

Test 1: IAM template YAML syntax... ✓ PASS
Test 2: Application template YAML syntax... ✓ PASS
Test 3: IAM template has IAM resources... ✓ PASS (24 roles, 8 policies)
Test 4: IAM template has required outputs... ✓ PASS (32 outputs)
Test 5: Application template has IAM parameters... ✓ PASS (32 parameters)
Test 6: Output/parameter name consistency... ✓ PASS
Test 7: Application has minimal inline IAM... ✓ PASS (2 app-specific roles allowed)
Test 8: Templates are valid CloudFormation format... ✓ PASS

============================================================
Test Suite 1: Template Validation - Summary
============================================================
Total tests: 8
Passed: 8
Failed: 0
Success rate: 100.0%
```

### Minimal Mode Deployment (No Certificate)

For full validation without certificates:

```bash
# 1. Set up test environment
export TEST_ENV="iam-test"
export AWS_REGION="us-east-1"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# 2. Create S3 buckets for templates and state
aws s3 mb "s3://quilt-templates-${TEST_ENV}-${AWS_ACCOUNT_ID}" --region "$AWS_REGION"
aws s3 mb "s3://quilt-tfstate-${TEST_ENV}-${AWS_ACCOUNT_ID}" --region "$AWS_REGION"

# 3. Upload CloudFormation templates
aws s3 cp test/fixtures/stable-iam.yaml \
  "s3://quilt-templates-${TEST_ENV}-${AWS_ACCOUNT_ID}/quilt-iam.yaml"
aws s3 cp test/fixtures/stable-app.yaml \
  "s3://quilt-templates-${TEST_ENV}-${AWS_ACCOUNT_ID}/quilt-app.yaml"

# 4. Create minimal test configuration
cat > test-config.tfvars << EOF
aws_region           = "${AWS_REGION}"
aws_account_id       = "${AWS_ACCOUNT_ID}"
test_environment     = "${TEST_ENV}"
google_client_secret = "test-secret"
okta_client_secret   = "test-secret"
certificate_arn      = ""  # Empty = HTTP only
create_dns_record    = false
db_instance_class    = "db.t3.micro"
search_instance_type = "t3.small.elasticsearch"
search_volume_size   = 10
EOF

# 5. Deploy with external IAM (see Testing Guide for full Terraform config)
# Follow spec/91-externalized-iam/07-testing-guide.md lines 179-218

# 6. Access via ALB DNS name (HTTP)
ALB_DNS=$(terraform output -raw alb_dns_name)
curl "http://${ALB_DNS}/health"

# 7. Cleanup when done
terraform destroy -var-file=test-config.tfvars
```

**How It Works**:

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

## Prerequisites

### Required Tools

```bash
# Verify tool versions
terraform --version  # >= 1.5.0
aws --version        # >= 2.x
python3 --version    # >= 3.8
uv --version         # Latest (for Python package management)
jq --version         # >= 1.6

# Install uv (if not already installed)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Optional but recommended
tfsec --version      # Security scanning
checkov --version    # Policy validation
```

### AWS Requirements

**For Template Validation Only** (Test Suite 1):

- AWS CLI configured with valid credentials
- No specific permissions required (templates validated locally)

**For Integration Testing** (Test Suites 3-7):

- Dedicated AWS test account (non-production recommended)
- Admin or PowerUser IAM permissions
- S3 bucket for Terraform state
- S3 bucket for CloudFormation templates

**Optional** (for full DNS/HTTPS testing):

- Route53 hosted zone
- ACM certificate
- Custom domain name

**Note**: All integration tests can run in **minimal mode** without Route53/ACM by using the ALB's DNS name directly (HTTP only). See "Testing Modes" section below.

### Python Dependencies

Automatically managed by `uv`:

- PyYAML - YAML parsing and validation

No manual installation needed - `run_validation.sh` handles dependencies.

## Test Structure

The test suite follows a test pyramid approach:

```text
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

### Test Suite 1: Template Validation (~5 min)

**Status**: ✅ **Implemented and Passing**

**Validates**:

- CloudFormation YAML syntax
- Template structure and sections
- IAM resource counts (31+ resources)
- IAM output counts (32 outputs)
- IAM parameter counts (32 parameters)
- Output/parameter name consistency
- Minimal inline IAM in application template
- CloudFormation format compliance

**Files**:

- `validate_templates.py` - Python validation script
- `run_validation.sh` - Shell wrapper

**Run**:

```bash
./run_validation.sh
```

### Test Suite 2: Terraform Module Validation (~5 min)

**Status**: ⏭️ To Be Implemented

**Validates**:

- Terraform syntax (`terraform validate`)
- Module formatting (`terraform fmt`)
- IAM module outputs (32 outputs)
- Quilt module variables (`iam_template_url`)
- Security scanning (tfsec/checkov)

**Reference**: [Testing Guide lines 495-587](../spec/91-externalized-iam/07-testing-guide.md)

### Test Suite 3: IAM Module Integration (~15 min)

**Status**: ⏭️ To Be Implemented

**Validates**:

- IAM module deployment
- CloudFormation stack creation
- IAM resource creation in AWS
- Output ARN format validation
- Stack status verification
- Resource tagging

**Reference**: [Testing Guide lines 590-810](../spec/91-externalized-iam/07-testing-guide.md)

### Test Suite 4: Full Module Integration (~30 min)

**Status**: ⏭️ To Be Implemented

**Validates**:

- Complete deployment (IAM + application stacks)
- Stack dependency handling
- IAM parameter propagation
- Application accessibility
- Health endpoint responses
- Database connectivity
- ElasticSearch connectivity
- ECS service running

**Reference**: [Testing Guide lines 812-1063](../spec/91-externalized-iam/07-testing-guide.md)

### Test Suite 5: Update Scenarios (~45 min)

**Status**: ⏭️ To Be Implemented

**Validates**:

- IAM policy updates (no ARN change)
- Infrastructure updates (no IAM impact)
- Update propagation
- Application stability during updates
- Stack independence

**Reference**: [Testing Guide lines 1065-1213](../spec/91-externalized-iam/07-testing-guide.md)

### Test Suite 6: Comparison Testing (~60 min)

**Status**: ⏭️ To Be Implemented

**Validates**:

- External IAM vs inline IAM equivalence
- Same IAM resources created
- Same application resources created
- Same functional behavior
- Comparable performance

**Reference**: [Testing Guide lines 1215-1345](../spec/91-externalized-iam/07-testing-guide.md)

### Test Suite 7: Deletion and Cleanup (~20 min)

**Status**: ⏭️ To Be Implemented

**Validates**:

- Proper deletion order (app stack → IAM stack)
- No orphaned IAM resources
- No orphaned CloudFormation exports
- Clean Terraform state
- Complete resource cleanup

**Reference**: [Testing Guide lines 1347-1446](../spec/91-externalized-iam/07-testing-guide.md)

## Running Tests

### Run Individual Test Suite

```bash
# Test Suite 1: Template Validation (currently implemented)
cd /Users/ernest/GitHub/iac/test
./run_validation.sh
```

### Run All Tests (When Implemented)

```bash
# Future: Master test runner
./run-all-tests.sh  # Will run suites 1-7 sequentially
```

### Run Tests with Verbose Output

```bash
# Python script with detailed output
uv run --with pyyaml validate_templates.py
```

### Check Test Results

```bash
# View latest test results
cat TEST_RESULTS.md

# View individual test logs (for integration tests)
ls -la test-results-*.log
```

## Testing Modes

### Minimal Mode (Recommended for Testing)

**Use when**: You want to validate IAM functionality without certificate/DNS overhead

**Requirements**:

- AWS account with test permissions
- No ACM certificate needed
- No Route53 zone needed

**Access method**: HTTP via ALB DNS name

**Configuration**:

```hcl
module "quilt" {
  source = "../modules/quilt"

  name = "quilt-iam-test"

  # External IAM configuration
  iam_template_url = "https://bucket.s3.amazonaws.com/quilt-iam.yaml"
  template_url     = "https://bucket.s3.amazonaws.com/quilt-app.yaml"

  # Minimal DNS/SSL config - NO CERTIFICATE NEEDED
  certificate_arn   = ""                    # Empty = HTTP only
  quilt_web_host    = "quilt-iam-test"      # Dummy value
  create_dns_record = false                 # Don't create Route53 record

  # Authentication (dummy values for testing)
  google_client_secret = "test-secret"
  okta_client_secret   = "test-secret"

  # Minimal sizing for cost efficiency
  db_instance_class    = "db.t3.micro"
  search_instance_type = "t3.small.elasticsearch"
  search_volume_size   = 10
}
```

**Testing**:

```bash
# Get ALB DNS name
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test with HTTP (no certificate needed)
curl -v "http://${ALB_DNS}/"
curl -v "http://${ALB_DNS}/health"
```

### Full Mode (Production-like)

**Use when**: You want to test complete production configuration

**Requirements**:

- AWS account with test permissions
- Valid ACM certificate
- Route53 hosted zone
- Custom domain name

**Access method**: HTTPS via custom domain

**Configuration**:

```hcl
module "quilt" {
  source = "../modules/quilt"

  name = "quilt-iam-test"

  # External IAM configuration
  iam_template_url = "https://bucket.s3.amazonaws.com/quilt-iam.yaml"
  template_url     = "https://bucket.s3.amazonaws.com/quilt-app.yaml"

  # Full DNS/SSL configuration
  certificate_arn   = "arn:aws:acm:us-east-1:123456789012:certificate/..."
  route53_zone_id   = "Z1234567890ABC"
  quilt_web_host    = "quilt-test.example.com"
  create_dns_record = true

  # Authentication
  google_client_secret = var.google_client_secret
  okta_client_secret   = var.okta_client_secret

  # Production-like sizing
  db_instance_class    = "db.t3.small"
  search_instance_type = "t3.medium.elasticsearch"
  search_volume_size   = 20
}
```

**Testing**:

```bash
# Test with HTTPS
curl -k "https://quilt-test.example.com/"
curl -k "https://quilt-test.example.com/health"
```

## Troubleshooting

### Template Validation Failures

**Problem**: YAML syntax errors

```bash
# Check template syntax manually
python3 -c "import yaml; yaml.safe_load(open('test/fixtures/stable-iam.yaml'))"

# Common issues:
# - Invalid indentation
# - Missing quotes in strings
# - Incorrect CloudFormation intrinsic functions
```

**Problem**: Output/parameter mismatches

```bash
# Run validation with detailed output
uv run --with pyyaml validate_templates.py

# Check specific output/parameter names
grep "^  .*Arn:" test/fixtures/stable-iam.yaml  # IAM outputs
grep "Role\|Policy" test/fixtures/stable-app.yaml | grep "Type: String"  # App parameters
```

**Problem**: Unexpected inline IAM resources

```bash
# Find inline IAM resources in application template
grep -E "Type:.*AWS::IAM::(Role|Policy|ManagedPolicy)" test/fixtures/stable-app.yaml

# Expected: Only app-specific helper roles (e.g., S3ObjectResourceHandlerRole)
# Not expected: Quilt core roles (e.g., AdminHandlerRole, PreviewRole, etc.)
```

### Module Integration Failures

**Problem**: Terraform init fails

```bash
# Clear Terraform cache
rm -rf .terraform .terraform.lock.hcl

# Re-initialize
terraform init -upgrade

# Check provider versions
terraform version
```

**Problem**: CloudFormation stack creation fails

```bash
# Check CloudFormation events
aws cloudformation describe-stack-events \
  --stack-name quilt-iam-test \
  --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`]' \
  --output table

# View detailed error
aws cloudformation describe-stack-events \
  --stack-name quilt-iam-test \
  --max-items 10 \
  --output json | jq '.StackEvents[] | select(.ResourceStatus=="CREATE_FAILED")'
```

**Problem**: IAM permissions errors

```bash
# Verify AWS credentials
aws sts get-caller-identity

# Check IAM permissions for CloudFormation
aws iam get-user --query 'User.Arn'

# Required permissions:
# - cloudformation:*
# - iam:*
# - s3:*
# - ec2:*
# - elasticloadbalancing:*
# - rds:*
# - es:*
```

### Deployment Timeouts

**Problem**: CloudFormation stack takes too long

```bash
# Increase timeout in Terraform
timeout 45m terraform apply -auto-approve

# Monitor progress
watch -n 30 'aws cloudformation describe-stacks \
  --stack-name quilt-iam-test \
  --query "Stacks[0].StackStatus" --output text'
```

**Problem**: ECS task stuck in PENDING

```bash
# Check ECS service events
aws ecs describe-services \
  --cluster quilt-iam-test \
  --services quilt-iam-test \
  --query 'services[0].events[0:5]'

# Common issues:
# - Insufficient ECS cluster capacity
# - IAM role missing permissions
# - Docker image pull failures
```

### Cleanup Issues

**Problem**: Stack deletion fails due to dependencies

```bash
# Check stack dependencies
aws cloudformation list-stack-resources \
  --stack-name quilt-iam-test \
  --query 'StackResourceSummaries[?ResourceStatus==`DELETE_FAILED`]'

# Manual cleanup order:
# 1. Delete application stack first
terraform destroy -target=module.quilt.aws_cloudformation_stack.app

# 2. Delete IAM stack second
terraform destroy -target=module.quilt.aws_cloudformation_stack.iam

# 3. Delete remaining resources
terraform destroy
```

**Problem**: Orphaned resources after deletion

```bash
# Find orphaned IAM roles
aws iam list-roles --query 'Roles[?starts_with(RoleName, `quilt-iam-test`)].RoleName'

# Find orphaned CloudFormation exports
aws cloudformation list-exports --query 'Exports[?starts_with(Name, `quilt-iam-test`)].Name'

# Manual cleanup (use with caution)
aws iam delete-role --role-name <role-name>
aws cloudformation delete-stack --stack-name <stack-name>
```

### Common Error Messages

#### "Stack with id X does not exist"

- Stack was deleted or never created
- Check stack name spelling
- Verify AWS region

#### "Parameter validation failed: Unknown parameter"

- IAM output name doesn't match application parameter
- Check output/parameter consistency with Test Suite 1

#### "Resource being created still exists"

- Previous test cleanup incomplete
- Manually delete CloudFormation stacks
- Clear Terraform state if necessary

## Cost Estimates

### Template Validation (Test Suite 1)

**Cost**: $0 (runs locally, no AWS resources)

### Integration Testing (Test Suites 3-7)

**Minimal Mode** (recommended):

| Resource | Instance Type | Hours | Cost/Hour | Total |
|----------|--------------|-------|-----------|-------|
| RDS Database | db.t3.micro | 3 | $0.017 | $0.05 |
| ElasticSearch | t3.small.elasticsearch | 3 | $0.036 | $0.11 |
| ECS (Fargate) | 0.5 vCPU, 1GB | 3 | $0.050 | $0.15 |
| ALB | Application Load Balancer | 3 | $0.025 | $0.08 |
| NAT Gateway | Single AZ | 3 | $0.045 | $0.14 |
| S3 Storage | 1GB | 30 days | $0.023 | $0.02 |
| Data Transfer | Minimal | - | - | $0.05 |
| **TOTAL** | | **~3 hours** | | **~$0.60** |

**Full Test Suite** (all 7 suites, with cleanup):

- Estimated duration: 3-4 hours
- Estimated cost: **$0.60-$0.80**

**Full Mode** (with Route53 and ACM):

Additional costs:

- Route53 Hosted Zone: $0.50/month (prorated)
- ACM Certificate: Free
- Additional data transfer: ~$0.05

**Total with Full Mode**: **~$0.70-$1.00**

### Cost Optimization Tips

1. **Use Minimal Mode**: Skip certificate/DNS for IAM testing (saves Route53 costs)
2. **Use Smallest Instances**:
   - `db.t3.micro` instead of `db.t3.small`
   - `t3.small.elasticsearch` instead of `t3.medium`
3. **Delete Immediately**: Run cleanup as soon as testing completes
4. **Use AWS Free Tier**: If available (750 hours/month of t3.micro)
5. **Test During Off-Peak**: Some regions have lower data transfer costs
6. **Share Test Environments**: Multiple developers can test against same deployment
7. **Automate Cleanup**: Set up CloudWatch alarms for cost overruns

### Preventing Cost Overruns

```bash
# Set up budget alert
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget file://budget.json

# budget.json example:
{
  "BudgetName": "IAM-Testing-Budget",
  "BudgetLimit": {
    "Amount": "5",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST"
}

# Tag all test resources
default_tags {
  tags = {
    Environment = "test"
    ManagedBy   = "terraform"
    TestSuite   = "externalized-iam"
    AutoDelete  = "true"
  }
}

# Schedule automatic cleanup (optional)
# Create Lambda function to delete test stacks after 8 hours
```

## Test Fixtures

Located in `fixtures/`:

- **stable-iam.yaml** - IAM-only CloudFormation template (31 IAM resources, 32 outputs)
- **stable-app.yaml** - Application CloudFormation template (infrastructure with parameterized IAM)
- **config.json** - AWS account configuration data
- **env** - Environment variables for testing

## Project Structure

```text
test/
├── README.md                    # This file
├── TEST_RESULTS.md             # Detailed test execution results
├── fixtures/                   # Test data
│   ├── stable-iam.yaml        # IAM template (31 resources)
│   ├── stable-app.yaml        # Application template
│   ├── stable.yaml            # Original monolithic template
│   ├── config.json            # AWS configuration
│   └── env                    # Environment variables
├── validate_templates.py       # Template validation script (Suite 1)
└── run_validation.sh          # Test runner for Suite 1
```

## Development

### Adding New Tests

1. Create test script in `test/` directory
2. Add test runner shell script (if needed)
3. Update this README with test description
4. Run tests and document results in TEST_RESULTS.md
5. Add to CI/CD pipeline

### Test Naming Convention

- Python scripts: `<test_suite_name>.py`
- Shell runners: `run_<test_suite_name>.sh`
- Make shell scripts executable: `chmod +x run_*.sh`

## CI/CD Integration

All test scripts return proper exit codes:

- `0` = All tests passed
- `1` = One or more tests failed

Example CI usage:

```bash
cd test
./run_validation.sh || exit 1
```

## References

- **[Testing Guide](../spec/91-externalized-iam/07-testing-guide.md)** - Complete testing specification with all 7 suites
- **[IAM Module Spec](../spec/91-externalized-iam/03-spec-iam-module.md)** - IAM module design and implementation
- **[Quilt Module Spec](../spec/91-externalized-iam/04-spec-quilt-module.md)** - Quilt module integration patterns
- **[Integration Spec](../spec/91-externalized-iam/05-spec-integration.md)** - Stack integration and dependencies
- **[Operations Guide](../OPERATIONS.md)** - Deployment procedures and operational guidance
- **[Issue #91](https://github.com/quiltdata/quilt-infrastructure/issues/91)** - Original feature request

## Next Steps

1. ✅ **Test Suite 1 Complete**: Template validation passing
2. ⏭️ **Implement Suite 2**: Terraform module validation
3. ⏭️ **Implement Suite 3**: IAM module integration
4. ⏭️ **Implement Suite 4**: Full module integration
5. ⏭️ **Implement Suite 5-7**: Update scenarios, comparison, cleanup

See [Testing Guide](../spec/91-externalized-iam/07-testing-guide.md) for complete implementation details.

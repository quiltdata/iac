# Deployment Script Usage Guide

This guide covers how to use the `tf_deploy.py` script to deploy Quilt infrastructure with externalized IAM.

## Prerequisites

1. **Python 3.8+** installed
2. **Terraform 1.0+** installed and in PATH
3. **AWS credentials** configured (via `aws configure` or environment variables)
4. **AWS permissions** to create CloudFormation stacks, IAM roles, and other resources

## Installation

No installation needed! Use `uv run` to automatically manage dependencies:

```bash
# Option 1: Run from deploy directory (recommended for relative paths)
cd deploy
uv run tf_deploy.py [command] [options]

# Option 2: Run from project root with --directory flag
uv run --directory deploy tf_deploy.py [command] [options]
```

Or install dependencies manually if preferred:

```bash
cd deploy
uv sync  # or: pip install -r requirements.txt
./tf_deploy.py [command] [options]
```

**Note:** The default config path is `../test/fixtures/config.json`, which works from both the deploy directory and when using `--directory deploy` from project root. No need to specify `--config` for the default test configuration.

## Quick Start

### 1. Deploy with External IAM Pattern

This is the recommended approach for the new externalized IAM feature:

```bash
# Dry run (plan only, no changes)
uv run tf_deploy.py deploy \
  --config ../test/fixtures/config.json \
  --pattern external-iam \
  --dry-run \
  --verbose

# Actual deployment
uv run tf_deploy.py deploy \
  --config ../test/fixtures/config.json \
  --pattern external-iam \
  --verbose

# With auto-approve (no prompts)
uv run tf_deploy.py deploy \
  --config ../test/fixtures/config.json \
  --pattern external-iam \
  --auto-approve
```

### 2. Deploy with Inline IAM Pattern (Legacy)

This maintains backward compatibility with existing deployments:

```bash
uv run tf_deploy.py deploy \
  --config ../test/fixtures/config.json \
  --pattern inline-iam
```

### 3. Validate Deployment

After deployment, validate that all resources are correctly configured:

```bash
uv run tf_deploy.py validate \
  --config ../test/fixtures/config.json \
  --verbose
```

### 4. Check Status

View the current status of your deployment:

```bash
uv run tf_deploy.py status \
  --config ../test/fixtures/config.json
```

### 5. View Outputs

Display Terraform outputs (URLs, stack IDs, etc.):

```bash
uv run tf_deploy.py outputs \
  --config ../test/fixtures/config.json
```

### 6. Destroy Stack

When you're done, tear down the infrastructure:

```bash
# With confirmation prompt
uv run tf_deploy.py destroy \
  --config ../test/fixtures/config.json

# Without confirmation (dangerous!)
uv run tf_deploy.py destroy \
  --config ../test/fixtures/config.json \
  --auto-approve
```

## Commands

### create

Generate Terraform configuration files without applying:

```bash
uv run tf_deploy.py create \
  --config ../test/fixtures/config.json \
  --pattern external-iam \
  --output-dir .deploy
```

**Output files:**

- `backend.tf` - Terraform backend and provider configuration
- `main.tf` - Main resource definitions
- `variables.tf` - Variable definitions
- `terraform.tfvars.json` - Variable values

### deploy

Full deployment workflow: create → init → validate → plan → apply

```bash
uv run tf_deploy.py deploy [OPTIONS]
```

**Options:**

- `--dry-run` - Plan only, don't apply changes
- `--stack-type {iam,app,both}` - Deploy specific stack type
- `--auto-approve` - Skip confirmation prompts
- `--verbose` - Enable detailed logging

**Workflow:**

1. Generates Terraform configuration from config.json
2. Runs `terraform init` to initialize providers
3. Runs `terraform validate` to check syntax
4. Runs `terraform plan` to preview changes
5. Prompts for confirmation (unless `--auto-approve`)
6. Runs `terraform apply` to create resources
7. Displays outputs

### validate

Validate deployed CloudFormation stacks:

```bash
uv run tf_deploy.py validate [OPTIONS]
```

**Validation tests:**

For **IAM stack** (external-iam pattern):

- Stack exists and status is CREATE_COMPLETE or UPDATE_COMPLETE
- Expected resource counts (24 IAM roles, 8 managed policies)
- All outputs are valid IAM ARNs
- IAM resources exist in AWS

For **Application stack**:

- Stack exists and status is successful
- All resources created
- IAM parameters injected correctly (external-iam pattern)
- Application is accessible via load balancer

### destroy

Tear down infrastructure:

```bash
uv run tf_deploy.py destroy [OPTIONS]
```

**Warning:** This is destructive and cannot be undone!

### status

Display deployment information:

```bash
uv run tf_deploy.py status [OPTIONS]
```

**Output:**

- Deployment name and pattern
- IAM stack name and ID (if external-iam)
- Application stack name and ID
- Quilt URL

### outputs

Show Terraform outputs:

```bash
uv run tf_deploy.py outputs [OPTIONS]
```

## Common Options

All commands support these options:

- `--config PATH` - Path to config.json (default: `../test/fixtures/config.json`)
- `--pattern {external-iam,inline-iam}` - Deployment pattern (default: `external-iam`)
- `--name NAME` - Override deployment name (default: from config)
- `--output-dir PATH` - Terraform output directory (default: `.deploy`)
- `--verbose, -v` - Enable verbose logging
- `--auto-approve` - Skip confirmation prompts

## Configuration File

The script reads `../test/fixtures/config.json` which contains:

```json
{
  "version": "1.0",
  "account_id": "712023778557",
  "region": "us-east-1",
  "environment": "iac",
  "domain": "quilttest.com",
  "email": "dev@quiltdata.io",
  "detected": {
    "vpcs": [...],
    "subnets": [...],
    "security_groups": [...],
    "certificates": [...],
    "route53_zones": [...]
  }
}
```

**Resource Selection Logic:**

The script automatically selects appropriate resources:

1. **VPC**: Prefers `quilt-staging` VPC, falls back to first non-default
2. **Subnets**: Selects 2+ public subnets in the chosen VPC
3. **Security Groups**: Finds in-use security groups in the VPC
4. **Certificate**: Matches wildcard certificate for domain (*.quilttest.com)
5. **Route53 Zone**: Matches public hosted zone for domain

## Exit Codes

- `0` - Success
- `1` - Configuration error
- `2` - Validation error
- `3` - Deployment error
- `4` - AWS API error
- `5` - Terraform error
- `6` - User cancelled

## Deployment Patterns

### External IAM Pattern

**What it does:**

1. Creates separate IAM CloudFormation stack with all roles/policies
2. Creates application CloudFormation stack with IAM parameters
3. Passes IAM ARNs from first stack to second stack as parameters

**Benefits:**

- IAM resources separated from application
- Can update application without touching IAM
- Better security boundary
- Supports IAM policy updates without redeployment

**Stacks created:**

- `{name}-iam` - IAM roles and policies
- `{name}` - Application resources

### Inline IAM Pattern

**What it does:**

1. Creates single monolithic CloudFormation stack
2. IAM roles/policies defined inline within template

**Benefits:**

- Backward compatible with existing deployments
- Simpler stack management
- Single stack to manage

**Stacks created:**

- `{name}` - All resources including IAM

## Troubleshooting

### Configuration Errors

**Problem:** `No suitable VPC found`

**Solution:** Ensure config.json has at least one non-default VPC

---

**Problem:** `Need at least 2 public subnets`

**Solution:** Ensure the selected VPC has 2+ public subnets

---

**Problem:** `No valid certificate found for domain`

**Solution:** Ensure ACM has a wildcard certificate (*.domain.com) in ISSUED status

### Terraform Errors

**Problem:** `terraform: command not found`

**Solution:** Install Terraform and ensure it's in PATH

---

**Problem:** `Error: Unauthorized`

**Solution:** Configure AWS credentials with `aws configure`

### Deployment Errors

**Problem:** CloudFormation stack creation fails

**Solution:** Check CloudFormation console for detailed error messages

---

**Problem:** Validation tests fail

**Solution:** Run with `--verbose` to see detailed validation results

## Examples

### Complete External IAM Deployment

```bash
# 1. Review what will be created
uv run tf_deploy.py deploy \
  --config ../test/fixtures/config.json \
  --pattern external-iam \
  --dry-run \
  --verbose

# 2. Deploy infrastructure
uv run tf_deploy.py deploy \
  --config ../test/fixtures/config.json \
  --pattern external-iam

# 3. Validate deployment
uv run tf_deploy.py validate \
  --config ../test/fixtures/config.json \
  --verbose

# 4. Check status
uv run tf_deploy.py status \
  --config ../test/fixtures/config.json

# 5. View outputs
uv run tf_deploy.py outputs \
  --config ../test/fixtures/config.json
```

### Custom Deployment Name

```bash
uv run tf_deploy.py deploy \
  --config ../test/fixtures/config.json \
  --pattern external-iam \
  --name my-custom-deployment
```

### CI/CD Usage

```bash
# Non-interactive deployment for CI/CD
uv run tf_deploy.py deploy \
  --config config.json \
  --pattern external-iam \
  --auto-approve \
  --verbose

# Exit code checking
if [ $? -eq 0 ]; then
  echo "Deployment successful"
else
  echo "Deployment failed with code $?"
  exit 1
fi
```

## Development

### Running Tests

```bash
# Run all tests
uv run pytest

# Run with coverage
uv run pytest --cov=lib --cov-report=html

# Run specific test file
uv run pytest tests/test_config.py -v
```

### Code Formatting

```bash
# Format code
uv run black .

# Lint code
uv run ruff check .

# Type check
uv run mypy lib/
```

## See Also

- [README.md](README.md) - Project overview
- [Specification](../spec/91-externalized-iam/08-tf-deploy-spec.md) - Detailed specification
- [Testing Guide](../spec/91-externalized-iam/07-testing-guide.md) - Testing procedures

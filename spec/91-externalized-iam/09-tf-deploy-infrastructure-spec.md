# Terraform Infrastructure Generation Specification

**Issue**: [#91 - externalized IAM](https://github.com/quiltdata/quilt-infrastructure/issues/91)

**Date**: 2025-11-20

**Branch**: 91-externalized-iam

**References**:
- [08-tf-deploy-spec.md](08-tf-deploy-spec.md) - Deployment script specification
- [examples/main.tf](../../examples/main.tf) - Reference Terraform configuration
- [OPERATIONS.md](../../OPERATIONS.md) - Operations guide

## Executive Summary

This specification defines how `deploy/tf_deploy.py` generates Terraform configuration files that:

1. **Create infrastructure** (VPC, RDS database, ElasticSearch) using Terraform
2. **Pass infrastructure outputs** to CloudFormation template as parameters
3. **Pass optional application parameters** (authentication config) to CloudFormation
4. **Ignore** truly optional parameters that have defaults in the template

## Problem Statement

The current `tf_deploy.py` implementation is trying to:
- Pass authentication parameters (Google, Okta, etc.) which are **optional**
- Pass infrastructure parameters (DB URL, Search endpoint) which don't exist yet
- Manage template uploads to S3

**The correct approach is**:
1. Terraform creates VPC, DB, Search (using `modules/quilt` module)
2. Terraform module outputs DB URL, Search endpoint, etc.
3. These outputs are passed as parameters to CloudFormation template
4. Optional authentication config can be omitted or passed via tfvars

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    tf_deploy.py                             │
│  Generates Terraform configuration from config.json         │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ↓
┌─────────────────────────────────────────────────────────────┐
│              Generated Terraform Configuration               │
│                                                              │
│  main.tf:                                                    │
│    module "quilt" {                                          │
│      source = "../../modules/quilt"                          │
│                                                              │
│      # Infrastructure configuration (REQUIRED)               │
│      name               = "quilt-iac-test"                   │
│      template_file      = "path/to/quilt-app.yaml"          │
│      create_new_vpc     = false                              │
│      vpc_id             = "vpc-010008ef3cce35c0c"            │
│      intra_subnets      = ["subnet-...", "subnet-..."]       │
│      private_subnets    = ["subnet-...", "subnet-..."]       │
│      public_subnets     = ["subnet-...", "subnet-..."]       │
│                                                              │
│      # Database configuration (REQUIRED)                     │
│      db_instance_class  = "db.t3.micro"                      │
│      db_multi_az        = false                              │
│                                                              │
│      # Search configuration (REQUIRED)                       │
│      search_instance_type = "t3.small.elasticsearch"         │
│      search_instance_count = 1                               │
│      search_volume_size = 10                                 │
│                                                              │
│      # CloudFormation parameters (REQUIRED)                  │
│      parameters = {                                          │
│        AdminEmail       = "dev@quiltdata.io"                 │
│        CertificateArnELB = "arn:aws:acm:..."                 │
│        QuiltWebHost     = "quilt-iac-test.quilttest.com"     │
│        PasswordAuth     = "Enabled"                          │
│      }                                                       │
│                                                              │
│      # Optional auth parameters (from tfvars if provided)    │
│      # parameters.GoogleClientSecret = var.google_secret     │
│    }                                                         │
│                                                              │
│  terraform.tfvars.json:                                      │
│    {                                                         │
│      "google_client_secret": "...",  # Only if configured    │
│      "okta_client_secret": "..."     # Only if configured    │
│    }                                                         │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ↓
┌──────────────────────┴──────────────────────────────────────┐
│                   Terraform Execution                        │
│                                                              │
│  1. terraform init                                           │
│  2. terraform plan                                           │
│  3. terraform apply                                          │
└──────────────────────┬──────────────────────────────────────┘
                       │
          ┌────────────┴────────────┐
          │                         │
          ↓                         ↓
┌──────────────────┐      ┌──────────────────┐
│  Terraform       │      │  CloudFormation  │
│  Infrastructure  │─────>│  Application     │
│                  │      │  Stack           │
│  - VPC           │      │                  │
│  - RDS Database  │      │  Parameters:     │
│  - ElasticSearch │      │  - DBUrl (from   │
│  - Security Grps │      │    TF output)    │
│                  │      │  - SearchDomain  │
│  Outputs:        │      │    (from TF)     │
│  - db_url        │      │  - AdminEmail    │
│  - search_domain │      │  - CertArn       │
│  - search_arn    │      │  - ...           │
└──────────────────┘      └──────────────────┘
```

## Required vs Optional Parameters

### Infrastructure Parameters (Terraform-managed, REQUIRED)

These are created by Terraform and passed to CloudFormation:

```python
INFRASTRUCTURE_PARAMS = {
    # Network (from Terraform VPC module)
    "vpc_id": "module.quilt outputs VPC ID",
    "subnet_ids": "module.quilt outputs subnet IDs",
    "security_group_ids": "module.quilt outputs SG IDs",

    # Database (from Terraform RDS module)
    "db_url": "module.quilt outputs database connection string",
    "db_password": "module.quilt generates and stores in Secrets Manager",

    # Search (from Terraform ElasticSearch module)
    "search_domain_arn": "module.quilt outputs ES domain ARN",
    "search_domain_endpoint": "module.quilt outputs ES endpoint",
}
```

### Application Parameters (REQUIRED)

These must be provided by the user:

```python
REQUIRED_APP_PARAMS = {
    "AdminEmail": "User email for admin account",
    "CertificateArnELB": "SSL certificate ARN for HTTPS",
    "QuiltWebHost": "Domain name for Quilt catalog",
    "PasswordAuth": "Enabled (always for initial setup)",
}
```

### Authentication Parameters (OPTIONAL)

These have defaults in the CloudFormation template and can be omitted:

```python
OPTIONAL_AUTH_PARAMS = {
    # Google OAuth (optional)
    "GoogleAuth": "Disabled",  # Default
    "GoogleClientId": "",       # Default
    "GoogleClientSecret": "",   # Default

    # Okta SAML/OAuth (optional)
    "OktaAuth": "Disabled",     # Default
    "OktaBaseUrl": "",          # Default
    "OktaClientId": "",         # Default
    "OktaClientSecret": "",     # Default

    # OneLogin OAuth (optional)
    "OneLoginAuth": "Disabled",         # Default
    "OneLoginBaseUrl": "",              # Default
    "OneLoginClientId": "",             # Default
    "OneLoginClientSecret": "",         # Default

    # Azure AD OAuth (optional)
    "AzureAuth": "Disabled",            # Default
    "AzureBaseUrl": "",                 # Default
    "AzureClientId": "",                # Default
    "AzureClientSecret": "",            # Default
}
```

### Other Optional Parameters

These have reasonable defaults:

```python
OTHER_OPTIONAL_PARAMS = {
    "CloudTrailBucket": "",                 # No CloudTrail by default
    "CanaryNotificationsEmail": "",         # No notifications by default
    "SingleSignOnDomains": "",              # No SSO domain restriction
    "Qurator": "Enabled",                   # Feature flag
    "ChunkedChecksums": "Enabled",          # Feature flag
    "ManagedUserRoleExtraPolicies": "",     # No extra policies
}
```

## Implementation Strategy

### 1. Update DeploymentConfig (lib/config.py)

Add methods to distinguish parameter types:

```python
@dataclass
class DeploymentConfig:
    """Deployment configuration."""

    # ... existing fields ...

    # Optional authentication config (if provided)
    google_client_secret: Optional[str] = None
    okta_client_secret: Optional[str] = None

    def get_required_cfn_parameters(self) -> Dict[str, str]:
        """Get required CloudFormation parameters.

        These are the minimal parameters needed for CloudFormation,
        assuming Terraform creates the infrastructure.
        """
        return {
            "AdminEmail": self.admin_email,
            "CertificateArnELB": self.certificate_arn,
            "QuiltWebHost": self.quilt_web_host,
            "PasswordAuth": "Enabled",  # Always enable for initial setup
        }

    def get_optional_cfn_parameters(self) -> Dict[str, str]:
        """Get optional CloudFormation parameters that were configured.

        Only returns parameters that were explicitly set.
        """
        params = {}

        # Google OAuth (only if configured)
        if self.google_client_secret:
            params.update({
                "GoogleAuth": "Enabled",
                "GoogleClientId": self.google_client_id,
                "GoogleClientSecret": self.google_client_secret,
            })

        # Okta OAuth (only if configured)
        if self.okta_client_secret:
            params.update({
                "OktaAuth": "Enabled",
                "OktaBaseUrl": self.okta_base_url,
                "OktaClientId": self.okta_client_id,
                "OktaClientSecret": self.okta_client_secret,
            })

        return params

    def get_terraform_infrastructure_config(self) -> Dict[str, any]:
        """Get Terraform infrastructure configuration.

        This configures the Terraform module to create:
        - VPC (or use existing)
        - RDS database
        - ElasticSearch domain
        - Security groups
        """
        config = {
            "name": self.deployment_name,
            "template_file": self.get_template_file_path(),

            # Network configuration
            "create_new_vpc": False,  # Use existing VPC from config
            "vpc_id": self.vpc_id,
            "intra_subnets": self._get_intra_subnets(),    # For DB & ES
            "private_subnets": self._get_private_subnets(), # For app
            "public_subnets": self.subnet_ids,              # For ALB
            "user_security_group": self.security_group_ids[0],

            # Database configuration
            "db_instance_class": self.db_instance_class,
            "db_multi_az": False,  # Single-AZ for testing
            "db_deletion_protection": False,  # Allow deletion for testing

            # ElasticSearch configuration
            "search_instance_type": self.search_instance_type,
            "search_instance_count": 1,  # Single node for testing
            "search_volume_size": self.search_volume_size,
            "search_dedicated_master_enabled": False,
            "search_zone_awareness_enabled": False,

            # CloudFormation parameters (required + optional)
            "parameters": {
                **self.get_required_cfn_parameters(),
                **self.get_optional_cfn_parameters(),
            }
        }

        # Add external IAM configuration if applicable
        if self.pattern == "external-iam":
            config["iam_template_url"] = self.iam_template_url
            config["template_url"] = self.app_template_url

        return config

    def _get_intra_subnets(self) -> List[str]:
        """Get isolated subnets for DB and ElasticSearch.

        These should be subnets with no internet access.
        If not available, use private subnets.
        """
        # For now, use the same as private subnets
        # TODO: Filter from config.json based on classification
        return self.subnet_ids[:2]

    def _get_private_subnets(self) -> List[str]:
        """Get private subnets for application.

        These should have NAT gateway access.
        """
        return self.subnet_ids[:2]

    def get_template_file_path(self) -> str:
        """Get path to CloudFormation template file.

        For testing, use local template file.
        For production, use S3 URL.
        """
        if self.pattern == "external-iam":
            # Use app-only template
            return str(Path(__file__).parent.parent.parent / "templates" / "quilt-app.yaml")
        else:
            # Use monolithic template
            return str(Path(__file__).parent.parent.parent / "templates" / "quilt-cfn.yaml")
```

### 2. Update Template Generation (lib/utils.py)

Generate Terraform configuration that uses the `quilt` module:

```python
def write_terraform_files(output_dir: Path, config: DeploymentConfig, pattern: str) -> None:
    """Write Terraform configuration files.

    Args:
        output_dir: Output directory for Terraform files
        config: Deployment configuration
        pattern: Deployment pattern ("external-iam" or "inline-iam")
    """
    output_dir.mkdir(parents=True, exist_ok=True)

    # Get infrastructure configuration
    infra_config = config.get_terraform_infrastructure_config()

    # Write main.tf
    main_tf = output_dir / "main.tf"
    main_tf.write_text(_generate_main_tf(infra_config, pattern))

    # Write variables.tf (for optional secrets)
    variables_tf = output_dir / "variables.tf"
    variables_tf.write_text(_generate_variables_tf(config))

    # Write terraform.tfvars.json (with actual values)
    tfvars = output_dir / "terraform.tfvars.json"
    tfvars.write_text(_generate_tfvars_json(config))

    # Write backend.tf (if needed)
    backend_tf = output_dir / "backend.tf"
    backend_tf.write_text(_generate_backend_tf(config))


def _generate_main_tf(config: Dict[str, any], pattern: str) -> str:
    """Generate main.tf content.

    Args:
        config: Infrastructure configuration
        pattern: Deployment pattern

    Returns:
        Terraform configuration as string
    """
    # Build parameters block
    params_lines = []
    for key, value in config["parameters"].items():
        # Only include non-empty values
        if value:
            if isinstance(value, str):
                params_lines.append(f'    {key} = "{value}"')
            else:
                params_lines.append(f'    {key} = {value}')
    params_block = "\n".join(params_lines)

    # Generate main.tf
    return f'''# Generated by tf_deploy.py
# Deployment: {config["name"]}
# Pattern: {pattern}

terraform {{
  required_version = ">= 1.5.0"
  required_providers {{
    aws = {{
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }}
  }}
}}

provider "aws" {{
  region = var.aws_region
}}

module "quilt" {{
  source = "../../modules/quilt"

  # Stack name
  name = "{config["name"]}"

  # Template
  template_file = "{config["template_file"]}"

  # Network configuration
  create_new_vpc = {str(config.get("create_new_vpc", False)).lower()}
  vpc_id         = "{config["vpc_id"]}"
  intra_subnets  = {json.dumps(config["intra_subnets"])}
  private_subnets = {json.dumps(config["private_subnets"])}
  public_subnets  = {json.dumps(config["public_subnets"])}
  user_security_group = "{config["user_security_group"]}"

  # Database configuration
  db_instance_class      = "{config["db_instance_class"]}"
  db_multi_az            = {str(config.get("db_multi_az", False)).lower()}
  db_deletion_protection = {str(config.get("db_deletion_protection", False)).lower()}

  # ElasticSearch configuration
  search_instance_type            = "{config["search_instance_type"]}"
  search_instance_count           = {config["search_instance_count"]}
  search_volume_size              = {config["search_volume_size"]}
  search_dedicated_master_enabled = {str(config.get("search_dedicated_master_enabled", False)).lower()}
  search_zone_awareness_enabled   = {str(config.get("search_zone_awareness_enabled", False)).lower()}

  # CloudFormation parameters
  parameters = {{
{params_block}
  }}
}}

# Outputs
output "stack_id" {{
  description = "CloudFormation stack ID"
  value       = module.quilt.stack.id
}}

output "stack_name" {{
  description = "CloudFormation stack name"
  value       = module.quilt.stack.stack_name
}}

output "admin_password" {{
  description = "Admin password"
  sensitive   = true
  value       = module.quilt.admin_password
}}

output "db_password" {{
  description = "Database password"
  sensitive   = true
  value       = module.quilt.db_password
}}

output "quilt_url" {{
  description = "Quilt catalog URL"
  value       = "https://{config["parameters"]["QuiltWebHost"]}"
}}
'''


def _generate_variables_tf(config: DeploymentConfig) -> str:
    """Generate variables.tf for optional secrets."""
    return f'''# Variables for optional secrets

variable "aws_region" {{
  description = "AWS region"
  type        = string
  default     = "{config.aws_region}"
}}

variable "google_client_secret" {{
  description = "Google OAuth client secret (optional)"
  type        = string
  default     = ""
  sensitive   = true
}}

variable "okta_client_secret" {{
  description = "Okta OAuth client secret (optional)"
  type        = string
  default     = ""
  sensitive   = true
}}
'''


def _generate_tfvars_json(config: DeploymentConfig) -> str:
    """Generate terraform.tfvars.json with actual values."""
    tfvars = {
        "aws_region": config.aws_region,
    }

    # Add secrets if configured
    if config.google_client_secret:
        tfvars["google_client_secret"] = config.google_client_secret

    if config.okta_client_secret:
        tfvars["okta_client_secret"] = config.okta_client_secret

    return json.dumps(tfvars, indent=2)


def _generate_backend_tf(config: DeploymentConfig) -> str:
    """Generate backend.tf for state storage."""
    return f'''# Terraform state backend configuration
# Using local state for testing
# For production, configure S3 backend

terraform {{
  backend "local" {{
    path = "terraform.tfstate"
  }}
}}
'''
```

### 3. Update DeploymentConfig.from_config_file()

Add logic to load optional authentication config if present:

```python
@classmethod
def from_config_file(cls, config_path: Path, **overrides) -> "DeploymentConfig":
    """Load configuration from config.json."""
    with open(config_path) as f:
        config = json.load(f)

    # ... existing selection logic ...

    return cls(
        # ... existing required fields ...

        # Optional authentication (from overrides or environment)
        google_client_secret=overrides.get("google_client_secret") or os.getenv("GOOGLE_CLIENT_SECRET"),
        okta_client_secret=overrides.get("okta_client_secret") or os.getenv("OKTA_CLIENT_SECRET"),
    )
```

## Usage Examples

### Example 1: Deploy with Minimal Configuration

```bash
# No authentication configured - uses password auth only
./deploy/tf_deploy.py deploy \
  --config test/fixtures/config.json \
  --pattern external-iam
```

Generated `terraform.tfvars.json`:
```json
{
  "aws_region": "us-east-1"
}
```

CloudFormation parameters:
```json
{
  "AdminEmail": "dev@quiltdata.io",
  "CertificateArnELB": "arn:aws:acm:...",
  "QuiltWebHost": "quilt-iac-test.quilttest.com",
  "PasswordAuth": "Enabled"
}
```

### Example 2: Deploy with Google OAuth

```bash
# Configure Google OAuth via environment variable
export GOOGLE_CLIENT_SECRET="your-secret"

./deploy/tf_deploy.py deploy \
  --config test/fixtures/config.json \
  --pattern external-iam \
  --google-client-id "your-client-id"
```

Generated `terraform.tfvars.json`:
```json
{
  "aws_region": "us-east-1",
  "google_client_secret": "your-secret"
}
```

CloudFormation parameters:
```json
{
  "AdminEmail": "dev@quiltdata.io",
  "CertificateArnELB": "arn:aws:acm:...",
  "QuiltWebHost": "quilt-iac-test.quilttest.com",
  "PasswordAuth": "Enabled",
  "GoogleAuth": "Enabled",
  "GoogleClientId": "your-client-id",
  "GoogleClientSecret": "your-secret"
}
```

## Key Design Decisions

### Decision 1: Terraform Creates Infrastructure

**Rationale**: The Quilt module is designed to create VPC, RDS, ElasticSearch via Terraform, then pass outputs to CloudFormation. This is evident from:
- `examples/main.tf` lines 97-120 (infrastructure config)
- `OPERATIONS.md` lines 222-224 (references to `module.db`, `module.search`)

### Decision 2: Optional Parameters Can Be Omitted

**Rationale**: CloudFormation templates have default values for optional parameters. There's no need to pass empty strings for every optional parameter. Only pass what's configured.

### Decision 3: Secrets via Environment Variables

**Rationale**: Following Terraform best practices:
- Sensitive values in `terraform.tfvars.json` (gitignored)
- Can also use environment variables (`TF_VAR_*`)
- Never commit secrets to git

### Decision 4: Local Template Files for Testing

**Rationale**: For testing, use local template files rather than requiring S3 upload. This simplifies the test cycle.

## Testing Strategy

### Unit Tests

```python
def test_get_required_cfn_parameters():
    """Test required CloudFormation parameters."""
    config = DeploymentConfig(
        deployment_name="test",
        admin_email="test@example.com",
        certificate_arn="arn:aws:acm:...",
        quilt_web_host="test.example.com",
        # ... other required fields ...
    )

    params = config.get_required_cfn_parameters()

    assert params == {
        "AdminEmail": "test@example.com",
        "CertificateArnELB": "arn:aws:acm:...",
        "QuiltWebHost": "test.example.com",
        "PasswordAuth": "Enabled",
    }


def test_optional_parameters_omitted_when_not_configured():
    """Test optional parameters are omitted."""
    config = DeploymentConfig(
        # ... required fields only ...
        google_client_secret=None,
        okta_client_secret=None,
    )

    params = config.get_optional_cfn_parameters()

    assert params == {}  # No optional params


def test_optional_parameters_included_when_configured():
    """Test optional parameters are included when configured."""
    config = DeploymentConfig(
        # ... required fields ...
        google_client_secret="secret123",
        google_client_id="client-id",
    )

    params = config.get_optional_cfn_parameters()

    assert params == {
        "GoogleAuth": "Enabled",
        "GoogleClientId": "client-id",
        "GoogleClientSecret": "secret123",
    }
```

### Integration Tests

```bash
# Test 1: Deploy with minimal config (no auth)
./deploy/tf_deploy.py deploy --config test/fixtures/config.json --dry-run

# Test 2: Verify generated Terraform is valid
cd .deploy
terraform validate

# Test 3: Verify parameters passed to CloudFormation
terraform show -json | jq '.values.root_module.child_modules[] | select(.address=="module.quilt") | .resources[] | select(.type=="aws_cloudformation_stack") | .values.parameters'
```

## Success Criteria

- ✅ Terraform creates VPC, RDS, ElasticSearch
- ✅ CloudFormation receives infrastructure outputs as parameters
- ✅ Required application parameters (AdminEmail, Cert, Host) are passed
- ✅ Optional authentication parameters only passed if configured
- ✅ Deployment succeeds with minimal configuration (password auth only)
- ✅ Deployment succeeds with Google OAuth configured
- ✅ No hardcoded secrets in generated files

## Migration from Current Implementation

1. **Remove S3 template upload logic** - use local template files for testing
2. **Remove authentication parameter requirements** - make them optional
3. **Add infrastructure configuration** - VPC, DB, Search sizing
4. **Update parameter generation** - separate required vs optional
5. **Update tests** - test both minimal and full configurations

## References

- [examples/main.tf](../../examples/main.tf) - Shows infrastructure config pattern
- [OPERATIONS.md](../../OPERATIONS.md) - Shows Terraform manages infrastructure
- [08-tf-deploy-spec.md](08-tf-deploy-spec.md) - Overall deployment script spec

# Deployment Examples

> **⚠️ CRITICAL WARNING**: All examples in this document contain placeholder values that MUST be replaced with your actual values before deployment. Do NOT use these examples directly without customization.
>
> **Required replacements:**
>
> - `YOUR-ACCOUNT-ID`: Replace with your AWS account ID
> - `YOUR-AWS-REGION`: Replace with your AWS region (e.g., us-east-1, us-west-2)
> - `YOUR-COMPANY`: Replace with your company/organization name
> - `YOUR-VPC-ID`: Replace with your VPC ID (e.g., vpc-abc12345)
> - `YOUR-*-SUBNET-*`: Replace with your subnet IDs (e.g., subnet-abc12345)
> - `YOUR-SECURITY-GROUP-ID`: Replace with your security group ID (e.g., sg-abc12345)
> - `YOUR-ROUTE53-ZONE-ID`: Replace with your Route53 hosted zone ID
> - All certificate ARNs, domain names, and other placeholder values
>

This document provides comprehensive examples for deploying Quilt using different configurations and scenarios.

## Parameter Example Style Guide

When adding new examples to this document, use these grouping conventions for consistency:

- `# REQUIRED` - Parameters needed for basic deployment (AdminEmail, CertificateArnELB, QuiltWebHost)
- `# AUTHENTICATION` - At least one auth method must be enabled (PasswordAuth, GoogleAuth, OktaAuth, etc.)
- `# [AUTH_TYPE]` - Parameters specific to auth provider (e.g., GOOGLE, AZURE, OKTA)
- `# OPTIONAL FEATURES` - Optional capabilities (Qurator, CloudTrail, CanaryNotifications, etc.)
- `# ADVANCED` - Advanced configurations (WAF, custom networking, IAM policies, etc.)

**Additional guidelines:**

- Add inline comments for clarity: `Parameter = "value"  # Brief explanation`
- End complex examples with: `# For complete parameter reference, see VARIABLES.md`
- Group related parameters logically within each section
- Maintain alphabetical ordering within groups when practical

**Why this structure?** 75% of real deployments use minimal 4-5 parameter configurations. This tiered approach helps users distinguish required vs optional parameters, reducing configuration errors and deployment time.

## Table of Contents

- [Basic Examples](#basic-examples)
- [ElasticSearch Sizing Examples](#elasticsearch-sizing-examples)
- [Authentication Examples](#authentication-examples)
- [Network Configuration Examples](#network-configuration-examples)
- [Production Examples](#production-examples)
- [Multi-Environment Examples](#multi-environment-examples)

## Basic Examples

### Minimal Development Setup

```hcl
provider "aws" {
  region = "YOUR-AWS-REGION"
}

terraform {
  backend "s3" {
    bucket = "YOUR-TERRAFORM-STATE-BUCKET"
    key    = "quilt/dev/terraform.tfstate"
    region = "YOUR-AWS-REGION"
  }
}

locals {
  name            = "quilt-dev"
  build_file_path = "./quilt-dev.yml"
  quilt_web_host  = "dev-data.YOUR-COMPANY.com"
}

module "quilt" {
  source = "github.com/quiltdata/iac//modules/quilt?ref=1.3.0"

  name          = local.name
  template_file = local.build_file_path

  internal       = false
  create_new_vpc = true
  cidr           = "10.0.0.0/16"

  # Development settings - cost optimized
  # Note: db.t3.small is the recommended minimum for stable performance
  # db.t3.micro may be too small for realistic dev workloads
  db_instance_class      = "db.t3.micro"
  db_multi_az            = false
  db_deletion_protection = false

  # Small ElasticSearch cluster
  search_dedicated_master_enabled = false
  search_zone_awareness_enabled   = false
  search_instance_count          = 1
  search_instance_type           = "m5.large.elasticsearch"
  search_volume_size             = 512

  parameters = {
    # REQUIRED - Core deployment configuration
    AdminEmail        = "dev@YOUR-COMPANY.com"
    CertificateArnELB = "arn:aws:acm:YOUR-AWS-REGION:YOUR-ACCOUNT-ID:certificate/YOUR-DEV-CERT-ID"
    QuiltWebHost      = local.quilt_web_host

    # AUTHENTICATION - At least one auth method must be enabled
    PasswordAuth      = "Enabled"

    # OPTIONAL FEATURES
    Qurator          = "Enabled"  # Data quality features
  }
}

# Optional: DNS configuration
module "cnames" {
  source = "github.com/quiltdata/iac//modules/cnames?ref=1.3.0"

  lb_dns_name    = module.quilt.stack.outputs.LoadBalancerDNSName
  quilt_web_host = local.quilt_web_host
  zone_id        = "YOUR-ROUTE53-ZONE-ID"
}

# Outputs
output "admin_password" {
  description = "Admin password"
  sensitive   = true
  value       = module.quilt.admin_password
}

output "quilt_url" {
  description = "Quilt catalog URL"
  value       = "https://${local.quilt_web_host}"
}
```

### Standard Production Setup

```hcl
provider "aws" {
  region              = "YOUR-AWS-REGION"
  allowed_account_ids = ["YOUR-ACCOUNT-ID"]

  default_tags {
    tags = {
      Environment = "production"
      Project     = "quilt"
      Owner       = "data-team"
    }
  }
}

terraform {
  backend "s3" {
    bucket         = "YOUR-TERRAFORM-STATE-BUCKET"
    key            = "quilt/prod/terraform.tfstate"
    region         = "YOUR-AWS-REGION"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

locals {
  name            = "quilt-prod"
  build_file_path = "./quilt-prod.yml"
  quilt_web_host  = "data.YOUR-COMPANY.com"
}

module "quilt" {
  source = "github.com/quiltdata/iac//modules/quilt?ref=1.3.0"

  name          = local.name
  template_file = local.build_file_path

  internal       = false
  create_new_vpc = true
  cidr           = "10.0.0.0/16"

  # Production database settings
  db_instance_class      = "db.t3.medium"
  db_multi_az            = true
  db_deletion_protection = true

  # Medium ElasticSearch cluster
  search_dedicated_master_enabled = true
  search_zone_awareness_enabled   = true
  search_instance_count          = 2
  search_instance_type           = "m5.xlarge.elasticsearch"
  search_volume_size             = 2048
  search_volume_type             = "gp3"

  # CloudFormation notifications
  stack_notification_arns = ["arn:aws:sns:YOUR-AWS-REGION:YOUR-ACCOUNT-ID:quilt-notifications"]

  parameters = {
    # REQUIRED - Core deployment configuration
    AdminEmail               = "admin@YOUR-COMPANY.com"
    CertificateArnELB        = "arn:aws:acm:YOUR-AWS-REGION:YOUR-ACCOUNT-ID:certificate/YOUR-PROD-CERT-ID"
    QuiltWebHost             = local.quilt_web_host

    # AUTHENTICATION - At least one auth method must be enabled
    PasswordAuth             = "Enabled"

    # OPTIONAL FEATURES
    CloudTrailBucket         = "YOUR-CLOUDTRAIL-BUCKET"  # Audit logging
    Qurator                  = "Enabled"  # Data quality features
    CanaryNotificationsEmail = "ops@YOUR-COMPANY.com"  # Monitoring alerts
  }
}

module "cnames" {
  source = "github.com/quiltdata/iac//modules/cnames?ref=1.3.0"

  lb_dns_name    = module.quilt.stack.outputs.LoadBalancerDNSName
  quilt_web_host = local.quilt_web_host
  zone_id        = "YOUR-ROUTE53-ZONE-ID"
}
```

## ElasticSearch Sizing Examples

### Small (Development/Testing)

**Use case**: Development, testing, small datasets (<100GB)

```hcl
module "quilt" {
  # ... other configuration ...

  search_dedicated_master_enabled = false
  search_zone_awareness_enabled   = false
  search_instance_count          = 1
  search_instance_type           = "m5.large.elasticsearch"
  search_volume_size             = 512
  search_volume_type             = "gp2"
}
```

### Medium (Default Production)

**Use case**: Standard production, moderate datasets (100GB-1TB)

```hcl
module "quilt" {
  # ... other configuration ...

  search_dedicated_master_enabled = true
  search_zone_awareness_enabled   = true
  search_instance_count          = 2
  search_instance_type           = "m5.xlarge.elasticsearch"
  search_volume_size             = 1024
  search_volume_type             = "gp2"
}
```

### Large (High Volume)

**Use case**: Large datasets (1TB-5TB), high query volume

```hcl
module "quilt" {
  # ... other configuration ...

  search_dedicated_master_enabled = true
  search_zone_awareness_enabled   = true
  search_instance_count          = 2
  search_instance_type           = "m5.xlarge.elasticsearch"
  search_volume_size             = 2048  # 2TB
  search_volume_type             = "gp3"
}
```

### X-Large (Enterprise)

**Use case**: Very large datasets (5TB-15TB), high performance requirements

```hcl
module "quilt" {
  # ... other configuration ...

  search_dedicated_master_enabled = true
  search_zone_awareness_enabled   = true
  search_instance_count          = 2
  search_instance_type           = "m5.2xlarge.elasticsearch"
  search_volume_size             = 3072  # 3TB
  search_volume_type             = "gp3"
  search_volume_iops             = 16000
}
```

### XX-Large (High Performance)

**Use case**: Massive datasets (15TB+), maximum performance

```hcl
module "quilt" {
  # ... other configuration ...

  search_dedicated_master_enabled = true
  search_zone_awareness_enabled   = true
  search_instance_count          = 2
  search_instance_type           = "m5.4xlarge.elasticsearch"
  search_volume_size             = 6144  # 6TB
  search_volume_type             = "gp3"
  search_volume_iops             = 18750
}
```

### XXXX-Large (Multi-Node Scale)

**Use case**: Extreme scale, multiple TB per node

```hcl
module "quilt" {
  # ... other configuration ...

  search_dedicated_master_enabled = true
  search_zone_awareness_enabled   = true
  search_instance_count          = 4
  search_instance_type           = "m5.12xlarge.elasticsearch"
  search_volume_size             = 18432  # 18TB per node
  search_volume_type             = "gp3"
  search_volume_iops             = 40000
  search_volume_throughput       = 1187
}
```

## Authentication Examples

### Google OAuth Integration

```hcl
# variables.tf
variable "google_client_secret" {
  description = "Google OAuth client secret"
  type        = string
  sensitive   = true
}

# main.tf
module "quilt" {
  # ... other configuration ...

  parameters = {
    # REQUIRED - Core deployment configuration
    AdminEmail          = "admin@YOUR-COMPANY.com"
    CertificateArnELB   = "arn:aws:acm:YOUR-AWS-REGION:YOUR-ACCOUNT-ID:certificate/YOUR-CERTIFICATE-ID"
    QuiltWebHost        = "data.YOUR-COMPANY.com"

    # AUTHENTICATION - At least one auth method must be enabled
    PasswordAuth        = "Enabled"

    # GOOGLE - Required when GoogleAuth = "Enabled"
    GoogleAuth          = "Enabled"
    GoogleClientId      = "YOUR-ACCOUNT-ID-abcdefghijklmnopqrstuvwxyz.apps.googleusercontent.com"
    GoogleClientSecret  = var.google_client_secret
    SingleSignOnDomains = "YOUR-COMPANY.com,subsidiary.com"  # Auto-login for these domains

    # OPTIONAL FEATURES
    Qurator            = "Enabled"

    # For complete parameter reference, see VARIABLES.md
  }
}
```

### Okta SAML/OAuth Integration

```hcl
# variables.tf
variable "okta_client_secret" {
  description = "Okta OAuth client secret"
  type        = string
  sensitive   = true
}

# main.tf
module "quilt" {
  # ... other configuration ...

  parameters = {
    # REQUIRED - Core deployment configuration
    AdminEmail          = "admin@YOUR-COMPANY.com"
    CertificateArnELB   = "arn:aws:acm:YOUR-AWS-REGION:YOUR-ACCOUNT-ID:certificate/YOUR-CERTIFICATE-ID"
    QuiltWebHost        = "data.YOUR-COMPANY.com"

    # AUTHENTICATION - At least one auth method must be enabled
    PasswordAuth        = "Enabled"

    # OKTA - Required when OktaAuth = "Enabled"
    OktaAuth           = "Enabled"
    OktaBaseUrl        = "https://company.okta.com/oauth2/default"
    OktaClientId       = "0oa1234567890abcdef"
    OktaClientSecret   = var.okta_client_secret
    SingleSignOnDomains = "YOUR-COMPANY.com"  # Auto-login for this domain

    # OPTIONAL FEATURES
    Qurator            = "Enabled"

    # For complete parameter reference, see VARIABLES.md
  }
}
```

### Azure AD Integration

```hcl
# variables.tf
variable "azure_client_secret" {
  description = "Azure AD OAuth client secret"
  type        = string
  sensitive   = true
}

# main.tf
module "quilt" {
  # ... other configuration ...

  parameters = {
    # REQUIRED - Core deployment configuration
    AdminEmail        = "admin@YOUR-COMPANY.com"
    CertificateArnELB = "arn:aws:acm:YOUR-AWS-REGION:YOUR-ACCOUNT-ID:certificate/YOUR-CERTIFICATE-ID"
    QuiltWebHost      = "data.YOUR-COMPANY.com"

    # AUTHENTICATION - At least one auth method must be enabled
    PasswordAuth      = "Enabled"

    # AZURE - Required when AzureAuth = "Enabled"
    AzureAuth         = "Enabled"
    AzureBaseUrl      = "https://login.microsoftonline.com/tenant-id/v2.0"
    AzureClientId     = "12345678-1234-1234-1234-YOUR-ACCOUNT-ID"
    AzureClientSecret = var.azure_client_secret

    # OPTIONAL FEATURES
    Qurator          = "Enabled"

    # For complete parameter reference, see VARIABLES.md
  }
}
```

### Multi-Provider Authentication

```hcl
module "quilt" {
  # ... other configuration ...

  parameters = {
    # REQUIRED - Core deployment configuration
    AdminEmail           = "admin@YOUR-COMPANY.com"
    CertificateArnELB    = "arn:aws:acm:YOUR-AWS-REGION:YOUR-ACCOUNT-ID:certificate/YOUR-CERTIFICATE-ID"
    QuiltWebHost         = "data.YOUR-COMPANY.com"

    # AUTHENTICATION - At least one auth method must be enabled
    PasswordAuth         = "Enabled"  # Fallback method

    # GOOGLE - Required when GoogleAuth = "Enabled"
    GoogleAuth          = "Enabled"
    GoogleClientId      = var.google_client_id
    GoogleClientSecret  = var.google_client_secret

    # OKTA - Required when OktaAuth = "Enabled"
    OktaAuth           = "Enabled"
    OktaBaseUrl        = "https://company.okta.com/oauth2/default"
    OktaClientId       = var.okta_client_id
    OktaClientSecret   = var.okta_client_secret

    SingleSignOnDomains = "YOUR-COMPANY.com,partner.com"  # Shared SSO domains

    # OPTIONAL FEATURES
    Qurator            = "Enabled"

    # For complete parameter reference, see VARIABLES.md
  }
}
```

## Network Configuration Examples

### Internet-Facing with New VPC

```hcl
module "quilt" {
  source = "github.com/quiltdata/iac//modules/quilt?ref=1.3.0"

  name          = "quilt-internet"
  template_file = "./quilt.yml"

  # Internet-facing configuration
  internal       = false
  create_new_vpc = true
  cidr           = "10.0.0.0/16"

  # VPC will be created with:
  # - Public subnets for ALB and NAT gateways
  # - Private subnets for Quilt services
  # - Isolated subnets for database and ElasticSearch

  parameters = {
    # REQUIRED - Core deployment configuration
    AdminEmail        = "admin@YOUR-COMPANY.com"
    CertificateArnELB = "arn:aws:acm:YOUR-AWS-REGION:YOUR-ACCOUNT-ID:certificate/YOUR-CERTIFICATE-ID"
    QuiltWebHost      = "data.YOUR-COMPANY.com"

    # AUTHENTICATION - At least one auth method must be enabled
    PasswordAuth      = "Enabled"

    # OPTIONAL FEATURES
    Qurator          = "Enabled"
  }
}
```

### Internal (VPN) with New VPC

```hcl
module "quilt" {
  source = "github.com/quiltdata/iac//modules/quilt?ref=1.3.0"

  name          = "quilt-internal"
  template_file = "./quilt.yml"

  # Internal configuration for VPN access
  internal       = true
  create_new_vpc = true
  cidr           = "10.1.0.0/16"

  # VPC will be created with:
  # - Private subnets for Quilt services and ALB
  # - Isolated subnets for database and ElasticSearch
  # - No public subnets (no internet gateway)

  parameters = {
    # REQUIRED - Core deployment configuration
    AdminEmail        = "admin@YOUR-COMPANY.com"
    CertificateArnELB = "arn:aws:acm:YOUR-AWS-REGION:YOUR-ACCOUNT-ID:certificate/YOUR-CERTIFICATE-ID"
    QuiltWebHost      = "internal-data.YOUR-COMPANY.com"

    # AUTHENTICATION - At least one auth method must be enabled
    PasswordAuth      = "Enabled"

    # OPTIONAL FEATURES
    Qurator          = "Enabled"
  }
}
```

### Existing VPC - Internet-Facing

```hcl
module "quilt" {
  source = "github.com/quiltdata/iac//modules/quilt?ref=1.3.0"

  name          = "quilt-existing"
  template_file = "./quilt.yml"

  # Use existing VPC
  create_new_vpc      = false
  internal           = false
  vpc_id             = "YOUR-VPC-ID"

  # Subnet configuration for internet-facing deployment
  intra_subnets       = ["YOUR-ISOLATED-SUBNET-1", "YOUR-ISOLATED-SUBNET-2"]    # For DB & ElasticSearch
  private_subnets     = ["YOUR-PRIVATE-SUBNET-1", "YOUR-PRIVATE-SUBNET-2"]      # For Quilt services
  public_subnets      = ["YOUR-PUBLIC-SUBNET-1", "YOUR-PUBLIC-SUBNET-2"]        # For ALB
  user_security_group = "YOUR-SECURITY-GROUP-ID"                                # For ALB access

  parameters = {
    # REQUIRED - Core deployment configuration
    AdminEmail        = "admin@YOUR-COMPANY.com"
    CertificateArnELB = "arn:aws:acm:YOUR-AWS-REGION:YOUR-ACCOUNT-ID:certificate/YOUR-CERTIFICATE-ID"
    QuiltWebHost      = "data.YOUR-COMPANY.com"

    # AUTHENTICATION - At least one auth method must be enabled
    PasswordAuth      = "Enabled"

    # OPTIONAL FEATURES
    Qurator          = "Enabled"
  }
}
```

### Existing VPC - Internal with VPC Endpoints

```hcl
# Create VPC endpoint for API Gateway
resource "aws_vpc_endpoint" "api_gateway" {
  vpc_id              = "YOUR-VPC-ID"
  service_name        = "com.amazonaws.YOUR-AWS-REGION.execute-api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = ["YOUR-PRIVATE-SUBNET-1", "YOUR-PRIVATE-SUBNET-2"]
  security_group_ids  = ["YOUR-SECURITY-GROUP-ID"]
  private_dns_enabled = true
}

module "quilt" {
  source = "github.com/quiltdata/iac//modules/quilt?ref=1.3.0"

  name          = "quilt-internal-existing"
  template_file = "./quilt.yml"

  # Use existing VPC for internal deployment
  create_new_vpc      = false
  internal           = true
  vpc_id             = "YOUR-VPC-ID"

  # Subnet configuration for internal deployment
  intra_subnets       = ["YOUR-ISOLATED-SUBNET-1", "YOUR-ISOLATED-SUBNET-2"]    # For DB & ElasticSearch
  private_subnets     = ["YOUR-PRIVATE-SUBNET-1", "YOUR-PRIVATE-SUBNET-2"]      # For Quilt services
  user_subnets        = ["YOUR-USER-SUBNET-1", "YOUR-USER-SUBNET-2"]           # For internal ALB
  user_security_group = "YOUR-SECURITY-GROUP-ID"                                # For ALB access
  api_endpoint        = aws_vpc_endpoint.api_gateway.id             # VPC endpoint

  parameters = {
    # REQUIRED - Core deployment configuration
    AdminEmail        = "admin@YOUR-COMPANY.com"
    CertificateArnELB = "arn:aws:acm:YOUR-AWS-REGION:YOUR-ACCOUNT-ID:certificate/YOUR-CERTIFICATE-ID"
    QuiltWebHost      = "internal-data.YOUR-COMPANY.com"

    # AUTHENTICATION - At least one auth method must be enabled
    PasswordAuth      = "Enabled"

    # OPTIONAL FEATURES
    Qurator          = "Enabled"
  }
}
```

## Production Examples

### High-Availability Production

```hcl
provider "aws" {
  region              = "YOUR-AWS-REGION"
  allowed_account_ids = ["YOUR-ACCOUNT-ID"]

  default_tags {
    tags = {
      Environment = "production"
      Project     = "quilt"
      CostCenter  = "data-platform"
      Backup      = "required"
    }
  }
}

terraform {
  backend "s3" {
    bucket         = "YOUR-TERRAFORM-STATE-BUCKET"
    key            = "quilt/prod/terraform.tfstate"
    region         = "YOUR-AWS-REGION"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

locals {
  name            = "quilt-prod"
  build_file_path = "./quilt-prod.yml"
  quilt_web_host  = "data.YOUR-COMPANY.com"
}

module "quilt" {
  source = "github.com/quiltdata/iac//modules/quilt?ref=1.3.0"

  name          = local.name
  template_file = local.build_file_path

  internal       = false
  create_new_vpc = true
  cidr           = "10.0.0.0/16"

  # High-availability database
  # Note: Real deployments use db.t3.small (default) to db.t3.large
  # Zero production deployments use r5 instances. Start with t3.large and scale if needed.
  db_instance_class      = "db.t3.large"
  db_multi_az            = true
  db_deletion_protection = true

  # High-performance ElasticSearch
  search_dedicated_master_enabled = true
  search_zone_awareness_enabled   = true
  # 4 nodes for extreme scale: Use for datasets >5TB or high query volume
  # Most production deployments use 2 nodes (the default). Scale up as needed.
  search_instance_count          = 4
  search_instance_type           = "m5.2xlarge.elasticsearch"
  search_volume_size             = 4096
  search_volume_type             = "gp3"
  search_volume_iops             = 16000

  # Monitoring and notifications
  stack_notification_arns = [
    "arn:aws:sns:YOUR-AWS-REGION:YOUR-ACCOUNT-ID:quilt-alerts",
    "arn:aws:sns:YOUR-AWS-REGION:YOUR-ACCOUNT-ID:ops-notifications"
  ]

  parameters = {
    # REQUIRED - Core deployment configuration
    AdminEmail                   = "admin@YOUR-COMPANY.com"
    CertificateArnELB           = "arn:aws:acm:YOUR-AWS-REGION:YOUR-ACCOUNT-ID:certificate/YOUR-PROD-CERT-ID"
    QuiltWebHost                = local.quilt_web_host

    # AUTHENTICATION - At least one auth method must be enabled
    PasswordAuth                = "Enabled"

    # OKTA - Required when OktaAuth = "Enabled"
    OktaAuth                    = "Enabled"
    OktaBaseUrl                 = "https://company.okta.com/oauth2/default"
    OktaClientId                = var.okta_client_id
    OktaClientSecret            = var.okta_client_secret
    SingleSignOnDomains         = "YOUR-COMPANY.com"

    # OPTIONAL FEATURES
    CloudTrailBucket            = "YOUR-CLOUDTRAIL-BUCKET-prod"  # Audit logging
    Qurator                     = "Enabled"  # Data quality features
    CanaryNotificationsEmail    = "ops@YOUR-COMPANY.com"  # Monitoring alerts

    # ADVANCED - Custom IAM policies and security
    ManagedUserRoleExtraPolicies = join(",", [
      "arn:aws:iam::YOUR-ACCOUNT-ID:policy/DataScientistAccess",
      "arn:aws:iam::aws:policy/AmazonAthenaFullAccess"
    ])
    WAFGeofenceCountries = "US,CA,GB,DE,FR,AU"  # Geographic restrictions

    # For complete parameter reference, see VARIABLES.md
  }
}

module "cnames" {
  source = "github.com/quiltdata/iac//modules/cnames?ref=1.3.0"

  lb_dns_name    = module.quilt.stack.outputs.LoadBalancerDNSName
  quilt_web_host = local.quilt_web_host
  zone_id        = "YOUR-ROUTE53-ZONE-ID"
}

# Outputs
output "admin_password" {
  description = "Admin password"
  sensitive   = true
  value       = module.quilt.admin_password
}

output "db_password" {
  description = "Database password"
  sensitive   = true
  value       = module.quilt.db_password
}

output "quilt_url" {
  description = "Quilt catalog URL"
  value       = "https://${local.quilt_web_host}"
}

output "load_balancer_dns" {
  description = "Load balancer DNS name"
  value       = module.quilt.stack.outputs.LoadBalancerDNSName
}
```

### Enterprise with Advanced Security

```hcl
module "quilt" {
  source = "github.com/quiltdata/iac//modules/quilt?ref=1.3.0"

  name          = "quilt-enterprise"
  template_file = "./quilt-enterprise.yml"

  internal       = true  # Internal deployment for security
  create_new_vpc = true
  cidr           = "10.10.0.0/16"

  # Enterprise-grade database
  # Note: This is a hypothetical extreme-scale example. No real deployments use r5 instances.
  # For actual enterprise needs, start with db.t3.xlarge and scale based on metrics.
  db_instance_class      = "db.t3.xlarge"
  db_multi_az            = true
  db_deletion_protection = true

  # High-performance ElasticSearch cluster
  search_dedicated_master_enabled = true
  search_zone_awareness_enabled   = true
  search_instance_count          = 6
  search_instance_type           = "m5.4xlarge.elasticsearch"
  search_volume_size             = 8192
  search_volume_type             = "gp3"
  search_volume_iops             = 20000
  search_volume_throughput       = 1000

  parameters = {
    # REQUIRED - Core deployment configuration
    AdminEmail                   = "admin@enterprise.com"
    CertificateArnELB           = "arn:aws:acm:YOUR-AWS-REGION:YOUR-ACCOUNT-ID:certificate/YOUR-ENTERPRISE-CERT-ID"
    QuiltWebHost                = "data.enterprise.com"

    # AUTHENTICATION - At least one auth method must be enabled
    PasswordAuth                = "Disabled"  # SSO only for enhanced security

    # OKTA - Required when OktaAuth = "Enabled"
    OktaAuth                    = "Enabled"
    OktaBaseUrl                 = "https://enterprise.okta.com/oauth2/default"
    OktaClientId                = var.okta_client_id
    OktaClientSecret            = var.okta_client_secret
    SingleSignOnDomains         = "enterprise.com"

    # OPTIONAL FEATURES
    CloudTrailBucket            = "enterprise-security-logs"  # Audit logging
    Qurator                     = "Enabled"  # Data quality features
    CanaryNotificationsEmail    = "security-ops@enterprise.com"  # Monitoring alerts

    # ADVANCED - Custom IAM policies and security
    ManagedUserRoleExtraPolicies = join(",", [
      "arn:aws:iam::YOUR-ACCOUNT-ID:policy/EnterpriseDataGovernance",
      "arn:aws:iam::YOUR-ACCOUNT-ID:policy/ComplianceAuditAccess",
      "arn:aws:iam::aws:policy/AmazonAthenaFullAccess"
    ])
    S3BucketPolicyExcludeArnsFromDeny = join(",", [
      "arn:aws:iam::YOUR-ACCOUNT-ID:role/DataGovernanceRole",
      "arn:aws:iam::YOUR-ACCOUNT-ID:role/ComplianceAuditRole"
    ])
    WAFGeofenceCountries = "US,CA"  # Restrict to North America only

    # For complete parameter reference, see VARIABLES.md
  }
}
```

## Multi-Environment Examples

### Using Terraform Workspaces

```hcl
# main.tf
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = terraform.workspace
      Project     = "quilt"
    }
  }
}

terraform {
  backend "s3" {
    bucket               = "YOUR-TERRAFORM-STATE-BUCKET"
    workspace_key_prefix = "quilt"
    key                  = "terraform.tfstate"
    region               = "YOUR-AWS-REGION"
  }
}

locals {
  # Environment-specific configuration
  config = {
    dev = {
      name                = "quilt-dev"
      cidr               = "10.0.0.0/16"
      db_instance_class  = "db.t3.micro"
      db_multi_az        = false
      search_instance_count = 1
      search_instance_type = "m5.large.elasticsearch"
      search_volume_size = 512
      cert_arn          = "arn:aws:acm:YOUR-AWS-REGION:YOUR-ACCOUNT-ID:certificate/YOUR-DEV-CERT-ID"
      web_host          = "dev-data.YOUR-COMPANY.com"
    }
    staging = {
      name                = "quilt-staging"
      cidr               = "10.1.0.0/16"
      db_instance_class  = "db.t3.small"
      db_multi_az        = true
      search_instance_count = 2
      search_instance_type = "m5.xlarge.elasticsearch"
      search_volume_size = 1024
      cert_arn          = "arn:aws:acm:YOUR-AWS-REGION:YOUR-ACCOUNT-ID:certificate/YOUR-STAGING-CERT-ID"
      web_host          = "staging-data.YOUR-COMPANY.com"
    }
    prod = {
      name                = "quilt-prod"
      cidr               = "10.2.0.0/16"
      db_instance_class  = "db.t3.large"
      db_multi_az        = true
      search_instance_count = 4
      search_instance_type = "m5.2xlarge.elasticsearch"
      search_volume_size = 4096
      cert_arn          = "arn:aws:acm:YOUR-AWS-REGION:YOUR-ACCOUNT-ID:certificate/YOUR-PROD-CERT-ID"
      web_host          = "data.YOUR-COMPANY.com"
    }
  }

  env_config = local.config[terraform.workspace]
}

module "quilt" {
  source = "github.com/quiltdata/iac//modules/quilt?ref=1.3.0"

  name          = local.env_config.name
  template_file = "./quilt-${terraform.workspace}.yml"

  internal       = false
  create_new_vpc = true
  cidr           = local.env_config.cidr

  # Environment-specific sizing
  db_instance_class      = local.env_config.db_instance_class
  db_multi_az            = local.env_config.db_multi_az
  db_deletion_protection = terraform.workspace == "prod"

  search_dedicated_master_enabled = local.env_config.search_instance_count > 1
  search_zone_awareness_enabled   = local.env_config.search_instance_count > 1
  search_instance_count          = local.env_config.search_instance_count
  search_instance_type           = local.env_config.search_instance_type
  search_volume_size             = local.env_config.search_volume_size

  parameters = {
    # REQUIRED - Core deployment configuration
    AdminEmail        = "admin+${terraform.workspace}@YOUR-COMPANY.com"
    CertificateArnELB = local.env_config.cert_arn
    QuiltWebHost      = local.env_config.web_host

    # AUTHENTICATION - At least one auth method must be enabled
    PasswordAuth      = "Enabled"

    # OPTIONAL FEATURES
    Qurator          = "Enabled"
  }
}

# Usage:
# terraform workspace new dev
# terraform workspace select dev
# terraform apply
```

### Separate Configuration Files

```hcl
# environments/dev/main.tf
module "quilt_dev" {
  source = "../../"

  name            = "quilt-dev"
  environment     = "dev"
  build_file_path = "./quilt-dev.yml"

  # Development overrides
  db_instance_class      = "db.t3.micro"
  db_multi_az            = false
  db_deletion_protection = false

  search_instance_count = 1
  search_instance_type  = "m5.large.elasticsearch"
  search_volume_size    = 512
}

# environments/prod/main.tf
module "quilt_prod" {
  source = "../../"

  name            = "quilt-prod"
  environment     = "prod"
  build_file_path = "./quilt-prod.yml"

  # Production settings
  # Note: Real deployments use db.t3.small (default) to db.t3.large
  # Zero production deployments use r5 instances. Start with t3.large and scale if needed.
  db_instance_class      = "db.t3.large"
  db_multi_az            = true
  db_deletion_protection = true

  # Large production: 4 data nodes for high availability and performance
  # Default is 2. Use 4 for datasets >5TB or high query volume (e.g., 45M docs, 11.5TB).
  search_instance_count = 4
  search_instance_type  = "m5.2xlarge.elasticsearch"
  search_volume_size    = 4096
  search_volume_type    = "gp3"
  search_volume_iops    = 16000
}
```

## Best Practices from Examples

### Security Best Practices

1. Use separate AWS accounts for different environments
2. Enable deletion protection for production databases (enabled by default)
3. Use internal ALBs for sensitive deployments
4. Implement WAF geofencing for additional security
5. Use SSO instead of password authentication where possible

### Performance Best Practices

1. Use Multi-AZ for production databases and ElasticSearch
2. Choose appropriate instance types based on workload
3. **Use gp3 volumes for better price/performance ratio**
   - gp3 provides ~20% cost savings vs gp2 for same performance
   - gp3 baseline: 3,000 IOPS, 125 MB/s (vs gp2's size-based performance)
   - Recommended for: Production workloads with >1TB storage
   - When to keep gp2: Small dev environments (<500GB) where simplicity matters
4. Configure IOPS and throughput for high-performance workloads
   - gp3 allows independent IOPS (up to 16,000) and throughput (up to 1,000 MB/s) tuning
   - See X-Large example (line 244) for high-IOPS configuration
5. Plan ElasticSearch storage with growth in mind
   - Estimate: (# documents) × (avg document size) × (1 + # replicas) × 1.5 safety factor
   - Real example: 45M docs × 256KB = 11.5TB requirement

### Operational Best Practices

1. Use remote state with locking
2. Tag all resources consistently
3. Set up monitoring and alerting
4. Use separate certificates for each environment
5. Implement proper backup strategies

### Cost Optimization

1. Use smaller instances for development environments
2. Disable Multi-AZ for non-production environments
3. Use gp3 volumes for better cost/performance (20% savings vs gp2 for equivalent performance)
4. Consider reserved instances for production workloads
5. Implement proper resource tagging for cost allocation

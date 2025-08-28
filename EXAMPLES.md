# Deployment Examples

This document provides comprehensive examples for deploying Quilt using different configurations and scenarios.

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
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "company-terraform-state"
    key    = "quilt/dev/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  name            = "quilt-dev"
  build_file_path = "./quilt-dev.yml"
  quilt_web_host  = "dev-data.company.com"
}

module "quilt" {
  source = "github.com/quiltdata/iac//modules/quilt?ref=1.3.0"

  name          = local.name
  template_file = local.build_file_path
  
  internal       = false
  create_new_vpc = true
  cidr           = "10.0.0.0/16"

  # Development settings - cost optimized
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
    AdminEmail        = "dev@company.com"
    CertificateArnELB = "arn:aws:acm:us-east-1:123456789012:certificate/dev-cert"
    QuiltWebHost      = local.quilt_web_host
    PasswordAuth      = "Enabled"
    Qurator          = "Enabled"
  }
}

# Optional: DNS configuration
module "cnames" {
  source = "github.com/quiltdata/iac//modules/cnames?ref=1.3.0"

  lb_dns_name    = module.quilt.stack.outputs.LoadBalancerDNSName
  quilt_web_host = local.quilt_web_host
  zone_id        = "Z1234567890ABC"
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
  region              = "us-east-1"
  allowed_account_ids = ["123456789012"]
  
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
    bucket         = "company-terraform-state"
    key            = "quilt/prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

locals {
  name            = "quilt-prod"
  build_file_path = "./quilt-prod.yml"
  quilt_web_host  = "data.company.com"
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
  stack_notification_arns = ["arn:aws:sns:us-east-1:123456789012:quilt-notifications"]

  parameters = {
    AdminEmail               = "admin@company.com"
    CertificateArnELB        = "arn:aws:acm:us-east-1:123456789012:certificate/prod-cert"
    QuiltWebHost             = local.quilt_web_host
    CloudTrailBucket         = "company-cloudtrail"
    PasswordAuth             = "Enabled"
    Qurator                  = "Enabled"
    CanaryNotificationsEmail = "ops@company.com"
  }
}

module "cnames" {
  source = "github.com/quiltdata/iac//modules/cnames?ref=1.3.0"

  lb_dns_name    = module.quilt.stack.outputs.LoadBalancerDNSName
  quilt_web_host = local.quilt_web_host
  zone_id        = "Z1234567890ABC"
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
    AdminEmail          = "admin@company.com"
    CertificateArnELB   = "arn:aws:acm:us-east-1:123456789012:certificate/cert-id"
    QuiltWebHost        = "data.company.com"
    PasswordAuth        = "Enabled"
    GoogleAuth          = "Enabled"
    GoogleClientId      = "123456789012-abcdefghijklmnopqrstuvwxyz.apps.googleusercontent.com"
    GoogleClientSecret  = var.google_client_secret
    SingleSignOnDomains = "company.com,subsidiary.com"
    Qurator            = "Enabled"
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
    AdminEmail          = "admin@company.com"
    CertificateArnELB   = "arn:aws:acm:us-east-1:123456789012:certificate/cert-id"
    QuiltWebHost        = "data.company.com"
    PasswordAuth        = "Enabled"
    OktaAuth           = "Enabled"
    OktaBaseUrl        = "https://company.okta.com/oauth2/default"
    OktaClientId       = "0oa1234567890abcdef"
    OktaClientSecret   = var.okta_client_secret
    SingleSignOnDomains = "company.com"
    Qurator            = "Enabled"
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
    AdminEmail        = "admin@company.com"
    CertificateArnELB = "arn:aws:acm:us-east-1:123456789012:certificate/cert-id"
    QuiltWebHost      = "data.company.com"
    PasswordAuth      = "Enabled"
    AzureAuth         = "Enabled"
    AzureBaseUrl      = "https://login.microsoftonline.com/tenant-id/v2.0"
    AzureClientId     = "12345678-1234-1234-1234-123456789012"
    AzureClientSecret = var.azure_client_secret
    Qurator          = "Enabled"
  }
}
```

### Multi-Provider Authentication

```hcl
module "quilt" {
  # ... other configuration ...
  
  parameters = {
    AdminEmail           = "admin@company.com"
    CertificateArnELB    = "arn:aws:acm:us-east-1:123456789012:certificate/cert-id"
    QuiltWebHost         = "data.company.com"
    
    # Enable multiple auth providers
    PasswordAuth         = "Enabled"
    GoogleAuth          = "Enabled"
    GoogleClientId      = var.google_client_id
    GoogleClientSecret  = var.google_client_secret
    OktaAuth           = "Enabled"
    OktaBaseUrl        = "https://company.okta.com/oauth2/default"
    OktaClientId       = var.okta_client_id
    OktaClientSecret   = var.okta_client_secret
    
    SingleSignOnDomains = "company.com,partner.com"
    Qurator            = "Enabled"
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
    AdminEmail        = "admin@company.com"
    CertificateArnELB = "arn:aws:acm:us-east-1:123456789012:certificate/cert-id"
    QuiltWebHost      = "data.company.com"
    PasswordAuth      = "Enabled"
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
    AdminEmail        = "admin@company.com"
    CertificateArnELB = "arn:aws:acm:us-east-1:123456789012:certificate/cert-id"
    QuiltWebHost      = "internal-data.company.com"
    PasswordAuth      = "Enabled"
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
  vpc_id             = "vpc-12345678"
  
  # Subnet configuration for internet-facing deployment
  intra_subnets       = ["subnet-isolated1", "subnet-isolated2"]    # For DB & ElasticSearch
  private_subnets     = ["subnet-private1", "subnet-private2"]      # For Quilt services
  public_subnets      = ["subnet-public1", "subnet-public2"]        # For ALB
  user_security_group = "sg-12345678"                               # For ALB access

  parameters = {
    AdminEmail        = "admin@company.com"
    CertificateArnELB = "arn:aws:acm:us-east-1:123456789012:certificate/cert-id"
    QuiltWebHost      = "data.company.com"
    PasswordAuth      = "Enabled"
    Qurator          = "Enabled"
  }
}
```

### Existing VPC - Internal with VPC Endpoints

```hcl
# Create VPC endpoint for API Gateway
resource "aws_vpc_endpoint" "api_gateway" {
  vpc_id              = "vpc-12345678"
  service_name        = "com.amazonaws.us-east-1.execute-api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = ["subnet-private1", "subnet-private2"]
  security_group_ids  = ["sg-12345678"]
  private_dns_enabled = true
}

module "quilt" {
  source = "github.com/quiltdata/iac//modules/quilt?ref=1.3.0"

  name          = "quilt-internal-existing"
  template_file = "./quilt.yml"
  
  # Use existing VPC for internal deployment
  create_new_vpc      = false
  internal           = true
  vpc_id             = "vpc-12345678"
  
  # Subnet configuration for internal deployment
  intra_subnets       = ["subnet-isolated1", "subnet-isolated2"]    # For DB & ElasticSearch
  private_subnets     = ["subnet-private1", "subnet-private2"]      # For Quilt services
  user_subnets        = ["subnet-user1", "subnet-user2"]           # For internal ALB
  user_security_group = "sg-12345678"                               # For ALB access
  api_endpoint        = aws_vpc_endpoint.api_gateway.id             # VPC endpoint

  parameters = {
    AdminEmail        = "admin@company.com"
    CertificateArnELB = "arn:aws:acm:us-east-1:123456789012:certificate/cert-id"
    QuiltWebHost      = "internal-data.company.com"
    PasswordAuth      = "Enabled"
    Qurator          = "Enabled"
  }
}
```

## Production Examples

### High-Availability Production

```hcl
provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = ["123456789012"]
  
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
    bucket         = "company-terraform-state"
    key            = "quilt/prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

locals {
  name            = "quilt-prod"
  build_file_path = "./quilt-prod.yml"
  quilt_web_host  = "data.company.com"
}

module "quilt" {
  source = "github.com/quiltdata/iac//modules/quilt?ref=1.3.0"

  name          = local.name
  template_file = local.build_file_path
  
  internal       = false
  create_new_vpc = true
  cidr           = "10.0.0.0/16"

  # High-availability database
  db_instance_class      = "db.r5.xlarge"
  db_multi_az            = true
  db_deletion_protection = true

  # High-performance ElasticSearch
  search_dedicated_master_enabled = true
  search_zone_awareness_enabled   = true
  search_instance_count          = 4
  search_instance_type           = "m5.2xlarge.elasticsearch"
  search_volume_size             = 4096
  search_volume_type             = "gp3"
  search_volume_iops             = 16000

  # Monitoring and notifications
  stack_notification_arns = [
    "arn:aws:sns:us-east-1:123456789012:quilt-alerts",
    "arn:aws:sns:us-east-1:123456789012:ops-notifications"
  ]

  parameters = {
    AdminEmail                   = "admin@company.com"
    CertificateArnELB           = "arn:aws:acm:us-east-1:123456789012:certificate/prod-cert"
    QuiltWebHost                = local.quilt_web_host
    CloudTrailBucket            = "company-cloudtrail-prod"
    PasswordAuth                = "Enabled"
    OktaAuth                    = "Enabled"
    OktaBaseUrl                 = "https://company.okta.com/oauth2/default"
    OktaClientId                = var.okta_client_id
    OktaClientSecret            = var.okta_client_secret
    SingleSignOnDomains         = "company.com"
    Qurator                     = "Enabled"
    CanaryNotificationsEmail    = "ops@company.com"
    ManagedUserRoleExtraPolicies = join(",", [
      "arn:aws:iam::123456789012:policy/DataScientistAccess",
      "arn:aws:iam::aws:policy/AmazonAthenaFullAccess"
    ])
    WAFGeofenceCountries = "US,CA,GB,DE,FR,AU"
  }
}

module "cnames" {
  source = "github.com/quiltdata/iac//modules/cnames?ref=1.3.0"

  lb_dns_name    = module.quilt.stack.outputs.LoadBalancerDNSName
  quilt_web_host = local.quilt_web_host
  zone_id        = "Z1234567890ABC"
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
  db_instance_class      = "db.r5.2xlarge"
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
    AdminEmail                   = "admin@enterprise.com"
    CertificateArnELB           = "arn:aws:acm:us-east-1:123456789012:certificate/enterprise-cert"
    QuiltWebHost                = "data.enterprise.com"
    CloudTrailBucket            = "enterprise-security-logs"
    PasswordAuth                = "Disabled"  # SSO only
    OktaAuth                    = "Enabled"
    OktaBaseUrl                 = "https://enterprise.okta.com/oauth2/default"
    OktaClientId                = var.okta_client_id
    OktaClientSecret            = var.okta_client_secret
    SingleSignOnDomains         = "enterprise.com"
    Qurator                     = "Enabled"
    CanaryNotificationsEmail    = "security-ops@enterprise.com"
    ManagedUserRoleExtraPolicies = join(",", [
      "arn:aws:iam::123456789012:policy/EnterpriseDataGovernance",
      "arn:aws:iam::123456789012:policy/ComplianceAuditAccess",
      "arn:aws:iam::aws:policy/AmazonAthenaFullAccess"
    ])
    S3BucketPolicyExcludeArnsFromDeny = join(",", [
      "arn:aws:iam::123456789012:role/DataGovernanceRole",
      "arn:aws:iam::123456789012:role/ComplianceAuditRole"
    ])
    WAFGeofenceCountries = "US,CA"  # Restrict to North America
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
    bucket               = "company-terraform-state"
    workspace_key_prefix = "quilt"
    key                  = "terraform.tfstate"
    region               = "us-east-1"
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
      cert_arn          = "arn:aws:acm:us-east-1:123456789012:certificate/dev-cert"
      web_host          = "dev-data.company.com"
    }
    staging = {
      name                = "quilt-staging"
      cidr               = "10.1.0.0/16"
      db_instance_class  = "db.t3.small"
      db_multi_az        = true
      search_instance_count = 2
      search_instance_type = "m5.xlarge.elasticsearch"
      search_volume_size = 1024
      cert_arn          = "arn:aws:acm:us-east-1:123456789012:certificate/staging-cert"
      web_host          = "staging-data.company.com"
    }
    prod = {
      name                = "quilt-prod"
      cidr               = "10.2.0.0/16"
      db_instance_class  = "db.r5.xlarge"
      db_multi_az        = true
      search_instance_count = 4
      search_instance_type = "m5.2xlarge.elasticsearch"
      search_volume_size = 4096
      cert_arn          = "arn:aws:acm:us-east-1:123456789012:certificate/prod-cert"
      web_host          = "data.company.com"
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
    AdminEmail        = "admin+${terraform.workspace}@company.com"
    CertificateArnELB = local.env_config.cert_arn
    QuiltWebHost      = local.env_config.web_host
    PasswordAuth      = "Enabled"
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
  db_instance_class      = "db.r5.xlarge"
  db_multi_az            = true
  db_deletion_protection = true
  
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
2. Enable deletion protection for production databases
3. Use internal ALBs for sensitive deployments
4. Implement WAF geofencing for additional security
5. Use SSO instead of password authentication where possible

### Performance Best Practices
1. Use Multi-AZ for production databases and ElasticSearch
2. Choose appropriate instance types based on workload
3. Use gp3 volumes for better price/performance ratio
4. Configure IOPS and throughput for high-performance workloads
5. Plan ElasticSearch storage with growth in mind

### Operational Best Practices
1. Use remote state with locking
2. Tag all resources consistently
3. Set up monitoring and alerting
4. Use separate certificates for each environment
5. Implement proper backup strategies

### Cost Optimization
1. Use smaller instances for development environments
2. Disable Multi-AZ for non-production environments
3. Use gp2 volumes for cost-sensitive workloads
4. Consider reserved instances for production workloads
5. Implement proper resource tagging for cost allocation

# Complete Variable Reference

This document provides comprehensive documentation for all variables available in the Quilt Terraform modules.

## Core Module Variables (`modules/quilt`)

### Required Variables

| Variable | Type | Description | Validation |
|----------|------|-------------|------------|
| `name` | `string` | Name for VPC, DB, CloudFormation stack, and resource prefix | ≤20 chars, lowercase alphanumeric + hyphens |
| `template_file` | `string` | Path to local CloudFormation template file | Must be a valid file path |
| `parameters` | `map(any)` | CloudFormation stack parameters | See [CloudFormation Parameters](#cloudformation-parameters) |
| `internal` | `bool` | Create internal ALB (true) or internet-facing ALB (false) | - |

### VPC Configuration Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `create_new_vpc` | `bool` | `false` | Create new VPC or use existing |
| `cidr` | `string` | `"10.0.0.0/16"` | VPC CIDR block (≥/24 for 256+ addresses) |
| `vpc_id` | `string` | `null` | Existing VPC ID (required if `create_new_vpc = false`) |
| `intra_subnets` | `list(string)` | `null` | Isolated subnet IDs (exactly 2 required for existing VPC) |
| `private_subnets` | `list(string)` | `null` | Private subnet IDs (exactly 2 required for existing VPC) |
| `public_subnets` | `list(string)` | `null` | Public subnet IDs (exactly 2 required for internet-facing ALB) |
| `user_subnets` | `list(string)` | `null` | ALB subnet IDs (exactly 2 required for internal ALB with existing VPC) |
| `user_security_group` | `string` | `null` | Security group ID for ALB access (required for existing VPC) |
| `api_endpoint` | `string` | `null` | VPC endpoint ID for API Gateway (required for internal ALB with existing VPC) |

### Database Configuration Variables

| Variable | Type | Default | Description | Valid Values |
|----------|------|---------|-------------|--------------|
| `db_instance_class` | `string` | `"db.t3.small"` | RDS instance class | `db.t3.micro`, `db.t3.small`, `db.t3.medium`, `db.t3.large`, `db.r5.*` |
| `db_multi_az` | `bool` | `true` | Enable Multi-AZ deployment for high availability | `true`, `false` |
| `db_network_type` | `string` | `"DUAL"` | Database network type | `"IPV4"`, `"DUAL"` |
| `db_deletion_protection` | `bool` | `true` | Prevent accidental database deletion | `true`, `false` |
| `db_snapshot_identifier` | `string` | `null` | Snapshot ID to restore database from | Valid RDS snapshot identifier |

### ElasticSearch Configuration Variables

| Variable | Type | Default | Description | Constraints |
|----------|------|---------|-------------|-------------|
| `search_instance_count` | `number` | `2` | Number of data nodes | ≥1 |
| `search_instance_type` | `string` | `"m5.xlarge.elasticsearch"` | Instance type for data nodes | Valid ES instance types |
| `search_dedicated_master_enabled` | `bool` | `true` | Enable dedicated master nodes | - |
| `search_dedicated_master_count` | `number` | `3` | Number of master nodes | 3 or 5 (odd numbers) |
| `search_dedicated_master_type` | `string` | `"m5.large.elasticsearch"` | Instance type for master nodes | Valid ES instance types |
| `search_zone_awareness_enabled` | `bool` | `true` | Enable Multi-AZ deployment | - |
| `search_volume_size` | `number` | `1024` | EBS volume size per data node (GiB) | ≥10 |
| `search_volume_type` | `string` | `"gp2"` | EBS volume type | `"gp2"`, `"gp3"`, `"io1"` |
| `search_volume_iops` | `number` | `null` | EBS IOPS (required for gp3) | ≥3000 if specified |
| `search_volume_throughput` | `number` | `null` | EBS throughput (MiB/s, for some gp3 volumes) | 125-1000 |
| `search_auto_tune_desired_state` | `string` | `"DISABLED"` | ElasticSearch Auto-Tune state | `"ENABLED"`, `"DISABLED"` |

### CloudFormation Stack Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `stack_notification_arns` | `list(string)` | `null` | SNS topic ARNs for CloudFormation notifications |
| `create_timeout` | `string` | `"30m"` | CloudFormation stack creation timeout |
| `update_timeout` | `string` | `"1h"` | CloudFormation stack update timeout |
| `delete_timeout` | `string` | `"1h30m"` | CloudFormation stack deletion timeout |
| `on_failure` | `string` | `"ROLLBACK"` | CloudFormation failure action |

## CloudFormation Parameters

The `parameters` map configures the Quilt application. Here are all available parameters:

### Required Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `AdminEmail` | Administrator email address | `"admin@company.com"` |
| `CertificateArnELB` | SSL certificate ARN for HTTPS | `"arn:aws:acm:us-east-1:123456789012:certificate/abc123"` |
| `QuiltWebHost` | Domain name for Quilt catalog | `"quilt.company.com"` |

### Authentication Parameters

| Parameter | Description | Values | Default |
|-----------|-------------|--------|---------|
| `PasswordAuth` | Enable username/password authentication | `"Enabled"`, `"Disabled"` | `"Enabled"` |
| `GoogleAuth` | Enable Google OAuth | `"Enabled"`, `"Disabled"` | `"Disabled"` |
| `GoogleClientId` | Google OAuth client ID | String | `""` |
| `GoogleClientSecret` | Google OAuth client secret | String (sensitive) | `""` |
| `OktaAuth` | Enable Okta SAML/OAuth | `"Enabled"`, `"Disabled"` | `"Disabled"` |
| `OktaBaseUrl` | Okta OAuth endpoint URL | `"https://company.okta.com/oauth2/default"` | `""` |
| `OktaClientId` | Okta OAuth client ID | String | `""` |
| `OktaClientSecret` | Okta OAuth client secret | String (sensitive) | `""` |
| `OneLoginAuth` | Enable OneLogin OAuth | `"Enabled"`, `"Disabled"` | `"Disabled"` |
| `OneLoginBaseUrl` | OneLogin OAuth endpoint URL | `"https://company.onelogin.com/oidc/2"` | `""` |
| `OneLoginClientId` | OneLogin OAuth client ID | String | `""` |
| `OneLoginClientSecret` | OneLogin OAuth client secret | String (sensitive) | `""` |
| `AzureAuth` | Enable Azure AD OAuth | `"Enabled"`, `"Disabled"` | `"Disabled"` |
| `AzureBaseUrl` | Azure AD OAuth endpoint URL | `"https://login.microsoftonline.com/tenant-id/v2.0"` | `""` |
| `AzureClientId` | Azure AD OAuth client ID | String | `""` |
| `AzureClientSecret` | Azure AD OAuth client secret | String (sensitive) | `""` |
| `SingleSignOnDomains` | Comma-separated list of SSO domains | `"company.com,subsidiary.com"` | `""` |

### Optional Application Parameters

| Parameter | Description | Example | Default |
|-----------|-------------|---------|---------|
| `CloudTrailBucket` | S3 bucket for CloudTrail logs | `"company-cloudtrail"` | `""` |
| `Qurator` | Enable Quilt's data quality features | `"Enabled"`, `"Disabled"` | `"Disabled"` |
| `CanaryNotificationsEmail` | Email for monitoring alerts | `"ops@company.com"` | `""` |
| `ChunkedChecksums` | Enable chunked checksums | `"Enabled"`, `"Disabled"` | `"Enabled"` |
| `VoilaVersion` | Voilà notebook version | `"0.5.8"` | Latest |

### Advanced Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `ManagedUserRoleExtraPolicies` | Additional IAM policies (comma-separated ARNs) | `"arn:aws:iam::123456789012:policy/CustomPolicy,arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"` |
| `S3BucketPolicyExcludeArnsFromDeny` | ARNs to exclude from S3 bucket deny policies | `"arn:aws:iam::123456789012:user/service-account,arn:aws:iam::123456789012:role/DataProcessingRole"` |
| `WAFGeofenceCountries` | Country codes for WAF geofencing (comma-separated) | `"US,CA,GB,DE,FR"` |

## VPC Module Variables (`modules/vpc`)

| Variable | Type | Description | Validation |
|----------|------|-------------|------------|
| `name` | `string` | VPC name prefix | - |
| `create_new_vpc` | `bool` | Create new VPC or use existing | - |
| `cidr` | `string` | VPC CIDR block | Prefix ≤ /24 |
| `internal` | `bool` | Internal or internet-facing deployment | - |
| `existing_vpc_id` | `string` | Existing VPC ID | - |
| `existing_api_endpoint` | `string` | Existing API Gateway VPC endpoint ID | - |
| `existing_intra_subnets` | `list(string)` | Existing isolated subnet IDs | Exactly 2 subnets |
| `existing_private_subnets` | `list(string)` | Existing private subnet IDs | Exactly 2 subnets |
| `existing_public_subnets` | `list(string)` | Existing public subnet IDs | Exactly 2 subnets |
| `existing_user_security_group` | `string` | Existing security group for ALB access | - |
| `existing_user_subnets` | `list(string)` | Existing subnets for ALB | Exactly 2 subnets |

## Database Module Variables (`modules/db`)

| Variable | Type | Description |
|----------|------|-------------|
| `identifier` | `string` | Database identifier |
| `vpc_id` | `string` | VPC ID for database |
| `subnet_ids` | `list(string)` | Subnet IDs for database |
| `snapshot_identifier` | `string` | Snapshot to restore from |
| `instance_class` | `string` | RDS instance class |
| `multi_az` | `bool` | Enable Multi-AZ |
| `network_type` | `string` | Network type (`"IPV4"` or `"DUAL"`) |
| `deletion_protection` | `bool` | Enable deletion protection |

## Search Module Variables (`modules/search`)

| Variable | Type | Description | Validation |
|----------|------|-------------|------------|
| `domain_name` | `string` | ElasticSearch domain name | - |
| `vpc_id` | `string` | VPC ID for ElasticSearch | - |
| `subnet_ids` | `list(string)` | Subnet IDs for ElasticSearch | - |
| `auto_tune_desired_state` | `string` | Auto-Tune state | - |
| `instance_count` | `number` | Number of data nodes | - |
| `instance_type` | `string` | Instance type for data nodes | - |
| `dedicated_master_enabled` | `bool` | Enable dedicated master nodes | - |
| `dedicated_master_count` | `number` | Number of master nodes | - |
| `dedicated_master_type` | `string` | Instance type for master nodes | - |
| `zone_awareness_enabled` | `bool` | Enable zone awareness | - |
| `volume_iops` | `number` | EBS IOPS | ≥3000 if specified |
| `volume_size` | `number` | EBS volume size (GiB) | - |
| `volume_throughput` | `number` | EBS throughput (MiB/s) | - |
| `volume_type` | `string` | EBS volume type | - |

## CNAMES Module Variables (`modules/cnames`)

| Variable | Type | Description |
|----------|------|-------------|
| `lb_dns_name` | `string` | Load balancer DNS name |
| `quilt_web_host` | `string` | Quilt web host domain |
| `ttl` | `number` | DNS record TTL (default: 60) |
| `zone_id` | `string` | Route53 hosted zone ID |

## Configuration Examples by Use Case

### Development Environment
```hcl
# Minimal cost configuration
db_instance_class               = "db.t3.micro"
db_multi_az                    = false
db_deletion_protection         = false
search_dedicated_master_enabled = false
search_zone_awareness_enabled  = false
search_instance_count          = 1
search_instance_type           = "m5.large.elasticsearch"
search_volume_size             = 512
```

### Production Environment
```hcl
# High availability configuration
db_instance_class               = "db.t3.medium"
db_multi_az                    = true
db_deletion_protection         = true
search_dedicated_master_enabled = true
search_zone_awareness_enabled  = true
search_instance_count          = 2
search_instance_type           = "m5.xlarge.elasticsearch"
search_volume_size             = 2048
search_volume_type             = "gp3"
```

### Enterprise Environment
```hcl
# High performance configuration
db_instance_class               = "db.r5.xlarge"
db_multi_az                    = true
db_deletion_protection         = true
search_dedicated_master_enabled = true
search_zone_awareness_enabled  = true
search_instance_count          = 4
search_instance_type           = "m5.4xlarge.elasticsearch"
search_volume_size             = 6144
search_volume_type             = "gp3"
search_volume_iops             = 18750
```

## Variable Validation Rules

### Name Validation
- Must be ≤20 characters
- Lowercase alphanumeric characters and hyphens only
- Used as prefix for AWS resource names

### Network Validation
- CIDR blocks must allow ≥256 IP addresses (≤/24)
- Subnet lists must contain exactly 2 subnet IDs when specified
- VPC endpoints required for internal deployments with existing VPC

### ElasticSearch Validation
- `search_volume_iops` must be ≥3000 when specified
- `search_volume_throughput` must be 125-1000 MiB/s for gp3 volumes
- Master node count should be odd (3 or 5) for proper quorum

### Database Validation
- `db_network_type` must be "IPV4" or "DUAL"
- Multi-AZ recommended for production environments
- Deletion protection recommended for production databases

## Common Configuration Patterns

### Internet-Facing with New VPC
```hcl
internal       = false
create_new_vpc = true
cidr          = "10.0.0.0/16"
# public_subnets, private_subnets, intra_subnets auto-created
```

### Internal with Existing VPC
```hcl
internal            = true
create_new_vpc      = false
vpc_id              = "vpc-existing"
intra_subnets       = ["subnet-1", "subnet-2"]
private_subnets     = ["subnet-3", "subnet-4"]
user_subnets        = ["subnet-5", "subnet-6"]
user_security_group = "sg-existing"
api_endpoint        = "vpce-existing"
```

### High-Performance ElasticSearch
```hcl
search_instance_type    = "m5.4xlarge.elasticsearch"
search_instance_count   = 4
search_volume_type      = "gp3"
search_volume_size      = 6144
search_volume_iops      = 18750
search_volume_throughput = 1000
```

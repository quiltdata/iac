# Quilt Platform Terraform Configuration Example
# 
# ⚠️  WARNING: This file contains placeholder values that MUST be replaced before use.
# Do NOT deploy this configuration without replacing ALL placeholder values with your actual values.
# 
# This is a comprehensive example showing how to deploy Quilt using Terraform.
# Copy this file to your project directory and customize the values below.
#
# Required replacements:
# - YOUR-ACCOUNT-ID: Replace with your AWS account ID
# - YOUR-AWS-REGION: Replace with your AWS region (e.g., us-east-1, us-west-2)
# - YOUR-COMPANY: Replace with your company/organization name
# - YOUR-TERRAFORM-STATE-BUCKET: Replace with your Terraform state bucket name
# - YOUR-CERT-ID: Replace with your SSL certificate ID
# - YOUR-ROUTE53-ZONE-ID: Replace with your Route53 hosted zone ID
# - All other YOUR-* placeholders with appropriate values

provider "aws" {
  # Replace with your AWS account ID
  allowed_account_ids = ["YOUR-ACCOUNT-ID"]
  # Replace with your preferred AWS region
  region              = "YOUR-AWS-REGION"
  
  default_tags {
    tags = {
      Project     = "quilt"
      Environment = "production"  # or "development", "staging"
      Owner       = "data-team"
      CostCenter  = "engineering"
    }
  }
}

terraform {
  # Configure remote state storage (recommended for production)
  backend "s3" {
    bucket         = "YOUR-TERRAFORM-STATE-BUCKET"
    key            = "quilt/terraform.tfstate"
    region         = "YOUR-AWS-REGION"
    encrypt        = true
    # Optional: DynamoDB table for state locking
    # dynamodb_table = "terraform-locks"
  }
  
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Local variables for configuration
locals {
  # Stack name (≤20 chars, lowercase alphanumeric + hyphens)
  name = "quilt-prod"
  
  # Path to your CloudFormation YAML template
  # Place a local copy of your CloudFormation YAML Template at build_file_path
  # and check it into git. Contact your account manager for the template.
  build_file_path = "./quilt-template.yml"
  
  # Your Quilt catalog domain name
  quilt_web_host = "data.YOUR-COMPANY.com"
}

# Optional: Variables for sensitive values
# Create a terraform.tfvars file or use environment variables
variable "google_client_secret" {
  description = "Google OAuth client secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "okta_client_secret" {
  description = "Okta OAuth client secret"
  type        = string
  sensitive   = true
  default     = ""
}

# Main Quilt module
module "quilt" {
  # Pin to the latest stable version from https://github.com/quiltdata/iac/tags
  source = "github.com/quiltdata/iac//modules/quilt?ref=1.3.0"

  name          = local.name
  template_file = local.build_file_path

  # Network configuration
  internal       = false  # Set to true for VPN-only access
  create_new_vpc = true   # Set to false to use existing VPC
  cidr           = "10.0.0.0/16"

  # Database configuration
  db_instance_class      = "db.t3.small"    # Adjust based on needs
  db_multi_az            = true             # High availability
  db_deletion_protection = true             # Prevent accidental deletion
  # db_network_type = "IPV4"                # Uncomment for IPv4-only VPCs
  # db_snapshot_identifier = "snap-12345"   # Uncomment to restore from snapshot

  # ElasticSearch configuration
  # Choose a sizing configuration based on your data volume:
  
  # Small (Development/Testing - <100GB data)
  # search_dedicated_master_enabled = false
  # search_zone_awareness_enabled   = false
  # search_instance_count          = 1
  # search_instance_type           = "m5.large.elasticsearch"
  # search_volume_size             = 512
  
  # Medium (Default Production - 100GB-1TB data)
  search_dedicated_master_enabled = true
  search_zone_awareness_enabled   = true
  search_instance_count          = 2
  search_instance_type           = "m5.xlarge.elasticsearch"
  search_volume_size             = 1024
  search_volume_type             = "gp2"
  
  # Large (High Volume - 1TB-5TB data)
  # search_dedicated_master_enabled = true
  # search_zone_awareness_enabled   = true
  # search_instance_count          = 2
  # search_instance_type           = "m5.xlarge.elasticsearch"
  # search_volume_size             = 2048
  # search_volume_type             = "gp3"
  
  # X-Large (Enterprise - 5TB-15TB data)
  # search_dedicated_master_enabled = true
  # search_zone_awareness_enabled   = true
  # search_instance_count          = 2
  # search_instance_type           = "m5.2xlarge.elasticsearch"
  # search_volume_size             = 3072
  # search_volume_type             = "gp3"
  # search_volume_iops             = 16000

  # Existing VPC configuration (uncomment if create_new_vpc = false)
  # vpc_id              = "vpc-YOUR-VPC-ID"
  # intra_subnets       = ["subnet-YOUR-INTRA-1", "subnet-YOUR-INTRA-2"]  # For DB & ElasticSearch
  # private_subnets     = ["subnet-YOUR-PRIVATE-1", "subnet-YOUR-PRIVATE-2"]  # For Quilt services
  # public_subnets      = ["subnet-YOUR-PUBLIC-1", "subnet-YOUR-PUBLIC-2"]  # For ALB (if internal = false)
  # user_security_group = "sg-YOUR-SECURITY-GROUP"                           # For ALB access
  # user_subnets        = ["subnet-YOUR-USER-1", "subnet-YOUR-USER-2"]  # For ALB (if internal = true)
  # api_endpoint        = "vpce-YOUR-VPC-ENDPOINT"                         # VPC endpoint (if internal = true)

  # CloudFormation notifications (optional)
  # stack_notification_arns = ["arn:aws:sns:YOUR-AWS-REGION:YOUR-ACCOUNT-ID:quilt-notifications"]

  # CloudFormation parameters
  parameters = {
    # Required parameters
    AdminEmail        = "admin@YOUR-COMPANY.com"
    CertificateArnELB = "arn:aws:acm:YOUR-AWS-REGION:YOUR-ACCOUNT-ID:certificate/YOUR-CERT-ID"
    QuiltWebHost      = local.quilt_web_host

    # Authentication configuration
    PasswordAuth = "Enabled"  # Always enable for initial setup
    
    # Google OAuth (optional)
    GoogleAuth         = "Disabled"  # Change to "Enabled" to use Google OAuth
    GoogleClientId     = ""          # Your Google OAuth client ID
    GoogleClientSecret = var.google_client_secret
    
    # Okta SAML/OAuth (optional)
    OktaAuth         = "Disabled"    # Change to "Enabled" to use Okta
    OktaBaseUrl      = ""            # https://YOUR-COMPANY.okta.com/oauth2/default
    OktaClientId     = ""            # Your Okta client ID
    OktaClientSecret = var.okta_client_secret
    
    # OneLogin OAuth (optional)
    OneLoginAuth         = "Disabled"  # Change to "Enabled" to use OneLogin
    OneLoginBaseUrl      = ""          # https://YOUR-COMPANY.onelogin.com/oidc/2
    OneLoginClientId     = ""          # Your OneLogin client ID
    OneLoginClientSecret = ""          # Your OneLogin client secret
    
    # Azure AD OAuth (optional)
    AzureAuth         = "Disabled"     # Change to "Enabled" to use Azure AD
    AzureBaseUrl      = ""             # https://login.microsoftonline.com/tenant-id/v2.0
    AzureClientId     = ""             # Your Azure AD client ID
    AzureClientSecret = ""             # Your Azure AD client secret
    
    # SSO domain restriction (optional)
    SingleSignOnDomains = ""           # Comma-separated list: "YOUR-COMPANY.com,subsidiary.com"

    # Optional features
    Qurator              = "Enabled"   # Enable Quilt's data quality features
    ChunkedChecksums     = "Enabled"   # Enable chunked checksums for large files
    CloudTrailBucket     = ""          # S3 bucket for CloudTrail logs
    CanaryNotificationsEmail = ""      # Email for monitoring alerts
    
    # Advanced configuration (optional)
    # ManagedUserRoleExtraPolicies = "arn:aws:iam::YOUR-ACCOUNT-ID:policy/CustomPolicy"
    # S3BucketPolicyExcludeArnsFromDeny = "arn:aws:iam::YOUR-ACCOUNT-ID:user/service-account"
    # WAFGeofenceCountries = "US,CA,GB"  # Country codes for WAF geofencing
    # VoilaVersion = "0.5.8"             # Specific Voilà version
  }
}

# DNS configuration (optional but recommended)
module "cnames" {
  source = "github.com/quiltdata/iac//modules/cnames?ref=1.3.0"

  lb_dns_name    = module.quilt.stack.outputs.LoadBalancerDNSName
  quilt_web_host = local.quilt_web_host
  zone_id        = "YOUR-ROUTE53-ZONE-ID"  # Your Route53 hosted zone ID
}

# Outputs
output "admin_password" {
  description = "Admin password for initial login"
  sensitive   = true
  value       = module.quilt.admin_password
}

output "db_password" {
  description = "Database password"
  sensitive   = true
  value       = module.quilt.db_password
}

output "admin_email" {
  description = "Admin email address"
  value       = module.quilt.stack.parameters.AdminEmail
}

output "quilt_url" {
  description = "Quilt catalog URL"
  value       = "https://${local.quilt_web_host}"
}

output "load_balancer_dns" {
  description = "Load balancer DNS name"
  value       = module.quilt.stack.outputs.LoadBalancerDNSName
}

# Example terraform.tfvars file content:
# 
# google_client_secret = "your-google-oauth-client-secret"
# okta_client_secret   = "your-okta-oauth-client-secret"

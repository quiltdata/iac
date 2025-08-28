# Quilt Platform Terraform Infrastructure

Deploy and maintain Quilt stacks with Terraform using this comprehensive Infrastructure as Code (IaC) repository.

## Table of Contents

- [Cloud Team Operations Guide](#cloud-team-operations-guide)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [ElasticSearch Configuration](#elasticsearch-configuration)
- [Database Configuration](#database-configuration)
- [Network Configuration](#network-configuration)
- [CloudFormation Parameters](#cloudformation-parameters)
- [Complete Variable Reference](#complete-variable-reference)
- [Deployment Examples](#deployment-examples)
- [Troubleshooting](#troubleshooting)
- [Terraform Commands Reference](#terraform-commands-reference)

## Cloud Team Operations Guide

This section provides step-by-step instructions specifically for cloud teams to ensure simple installation and maintenance of the Quilt platform.

### Initial Setup Checklist

#### 1. Environment Preparation (15 minutes)

**Step 1.1: Install Required Tools**
```bash
# Install Terraform (if not already installed)
# macOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Verify installation
terraform --version  # Should show >= 1.5.0
```

**Step 1.2: Configure AWS CLI**
```bash
# Install AWS CLI (if not already installed)
# macOS
brew install awscli

# Configure AWS credentials
aws configure
# Enter: Access Key ID, Secret Access Key, Region, Output format (json)

# Verify access
aws sts get-caller-identity
```

**Step 1.3: Set Up Terraform State Backend**
```bash
# Create S3 bucket for Terraform state (one-time setup)
aws s3 mb s3://YOUR-COMPANY-terraform-state --region YOUR-AWS-REGION

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket YOUR-COMPANY-terraform-state \
  --versioning-configuration Status=Enabled

# Optional: Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region YOUR-AWS-REGION
```

#### 2. SSL Certificate Setup (10 minutes)

**Step 2.1: Request SSL Certificate**
```bash
# Request certificate in AWS Certificate Manager
aws acm request-certificate \
  --domain-name "data.YOUR-COMPANY.com" \
  --subject-alternative-names "*.data.YOUR-COMPANY.com" \
  --validation-method DNS \
  --region YOUR-AWS-REGION

# Note the CertificateArn from the output
```

**Step 2.2: Validate Certificate**
```bash
# Get validation records
aws acm describe-certificate --certificate-arn "arn:aws:acm:YOUR-AWS-REGION:YOUR-ACCOUNT-ID:certificate/YOUR-CERT-ID"

# Add the DNS validation records to your domain's DNS
# Wait for validation (usually 5-10 minutes)
```

#### 3. Project Setup (10 minutes)

**Step 3.1: Create Project Directory**
```bash
# Create project directory
mkdir quilt-production
cd quilt-production

# Initialize git repository
git init
```

**Step 3.2: Download Template Files**
```bash
# Download the example configuration
curl -o main.tf https://raw.githubusercontent.com/quiltdata/iac/main/examples/main.tf

# Create variables file for sensitive data
cat > terraform.tfvars << 'EOF'
# Add your sensitive variables here
google_client_secret = "your-google-oauth-secret"
okta_client_secret   = "your-okta-oauth-secret"
EOF

# Create .gitignore
cat > .gitignore << 'EOF'
.terraform/
*.tfplan
*.tfstate
*.tfstate.backup
terraform.tfvars
.terraform.lock.hcl
EOF
```

**Step 3.3: Obtain CloudFormation Template**
Contact your Quilt account manager to obtain the CloudFormation template file and save it as `quilt-template.yml` in your project directory.

### Installation Process (30 minutes)

#### Step 1: Configure Your Deployment

**Edit main.tf with your specific values:**
```bash
# Open main.tf in your preferred editor
vim main.tf  # or code main.tf, nano main.tf, etc.
```

**⚠️ CRITICAL: Replace ALL placeholder values before deployment**

**Required changes:**
1. **AWS Account ID**: Replace `"YOUR-ACCOUNT-ID"` with your AWS account ID
2. **AWS Region**: Replace `"YOUR-AWS-REGION"` with your preferred AWS region
3. **S3 Backend**: Replace `"YOUR-TERRAFORM-STATE-BUCKET"` with your bucket name
4. **Stack Name**: Update `local.name` (≤20 chars, lowercase + hyphens)
5. **Domain**: Replace `"YOUR-COMPANY"` in `local.quilt_web_host` with your domain
6. **Certificate ARN**: Replace `"YOUR-CERT-ID"` with your SSL certificate ID
7. **Route53 Zone**: Replace `"YOUR-ROUTE53-ZONE-ID"` with your hosted zone ID
8. **All other placeholders**: Replace any remaining `YOUR-*` values with actual values

> **⚠️ WARNING**: Do NOT run `terraform apply` with placeholder values. This will cause deployment failures and may create resources with incorrect configurations.

**Choose ElasticSearch sizing based on your data volume:**
- **Small** (< 100GB): Use commented "Small" configuration
- **Medium** (100GB-1TB): Use default configuration (already uncommented)
- **Large** (1TB-5TB): Uncomment "Large" configuration
- **Enterprise** (5TB+): Uncomment "X-Large" or larger configuration

#### Step 2: Initialize and Plan

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt

# Create execution plan
terraform plan -out=tfplan

# Review the plan carefully - ensure no unexpected resource deletions
```

#### Step 3: Deploy

```bash
# Apply the configuration
terraform apply tfplan

# Deployment typically takes 20-30 minutes
# Monitor progress in AWS Console if needed
```

#### Step 4: Verify Deployment

```bash
# Get outputs
terraform output admin_password  # Save this password securely
terraform output quilt_url       # Your Quilt catalog URL

# Test access
curl -I https://data.YOUR-COMPANY.com  # Should return 200 OK
```

#### Step 5: Initial Configuration

1. **Access Quilt Catalog**: Navigate to your Quilt URL
2. **Login**: Use admin email and the password from terraform output
3. **Change Password**: Immediately change the default admin password
4. **Configure Users**: Set up additional users and permissions as needed

### Maintenance Procedures

#### Daily Operations

**Health Checks (5 minutes daily)**
```bash
# Check infrastructure status
terraform refresh
terraform plan  # Should show "No changes"

# Check application health
curl -f https://data.YOUR-COMPANY.com/health || echo "Health check failed"

# Check ElasticSearch cluster health
aws es describe-elasticsearch-domain --domain-name your-stack-name
```

#### Weekly Maintenance

**Backup Verification (10 minutes weekly)**
```bash
# Verify RDS automated backups
aws rds describe-db-snapshots --db-instance-identifier your-stack-name

# Check ElasticSearch snapshots (if configured)
aws es describe-elasticsearch-domain --domain-name your-stack-name
```

**Security Updates (15 minutes weekly)**
```bash
# Check for Terraform module updates
# Visit: https://github.com/quiltdata/iac/releases

# Update to latest stable version if available
# Edit main.tf and update the ref= parameter
# Example: ref=1.3.0 -> ref=1.4.0
```

#### Monthly Maintenance

**Capacity Planning (20 minutes monthly)**
```bash
# Check ElasticSearch storage usage
aws cloudwatch get-metric-statistics \
  --namespace AWS/ES \
  --metric-name StorageUtilization \
  --dimensions Name=DomainName,Value=YOUR-STACK-NAME Name=ClientId,Value=YOUR-ACCOUNT-ID \
  --start-time $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 86400 \
  --statistics Average

# Check RDS storage usage
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBInstanceIdentifier,Value=your-stack-name \
  --start-time $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 86400 \
  --statistics Average
```

### Scaling Operations

#### ElasticSearch Storage Scaling

**When to Scale**: When storage utilization > 80%

**Step 1: Plan the Scaling**
```bash
# Current configuration check
terraform show | grep search_volume_size

# Calculate new size needed (current_size * 1.5 recommended)
# Example: 1024GB -> 1536GB
```

**Step 2: Update Configuration**
```bash
# Edit main.tf
vim main.tf

# Update search_volume_size value
# Example: search_volume_size = 1536

# Plan the change
terraform plan -out=tfplan
```

**Step 3: Apply During Maintenance Window**
```bash
# Schedule during low-usage period
# Scaling causes temporary performance impact

terraform apply tfplan

# Monitor the scaling process
aws es describe-elasticsearch-domain --domain-name your-stack-name
```

#### Database Scaling

**Vertical Scaling (Instance Size)**
```bash
# Edit main.tf
# Update db_instance_class
# Example: db.t3.small -> db.t3.medium

terraform plan -out=tfplan
terraform apply tfplan  # Causes brief downtime
```

**Storage Scaling**
```bash
# RDS storage scales automatically if enabled
# Check current storage
aws rds describe-db-instances --db-instance-identifier your-stack-name
```

### Disaster Recovery

#### Backup Procedures

**Database Backup**
```bash
# Create manual snapshot
aws rds create-db-snapshot \
  --db-instance-identifier your-stack-name \
  --db-snapshot-identifier your-stack-name-manual-$(date +%Y%m%d)
```

**Configuration Backup**
```bash
# Backup Terraform state
aws s3 cp s3://YOUR-TERRAFORM-STATE-BUCKET/quilt/terraform.tfstate \
  ./terraform.tfstate.backup.$(date +%Y%m%d)

# Backup configuration files
tar -czf quilt-config-backup-$(date +%Y%m%d).tar.gz *.tf *.yml
```

#### Recovery Procedures

**Database Recovery**
```bash
# List available snapshots
aws rds describe-db-snapshots --db-instance-identifier your-stack-name

# Restore from snapshot (update main.tf)
# Add: db_snapshot_identifier = "snapshot-name"
# Then: terraform plan && terraform apply
```

### Monitoring and Alerting Setup

#### CloudWatch Alarms

**ElasticSearch Monitoring**
```bash
# Create storage utilization alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "Quilt-ES-Storage-High" \
  --alarm-description "ElasticSearch storage utilization > 80%" \
  --metric-name StorageUtilization \
  --namespace AWS/ES \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=DomainName,Value=YOUR-STACK-NAME Name=ClientId,Value=YOUR-ACCOUNT-ID \
  --evaluation-periods 2 \
  --alarm-actions arn:aws:sns:YOUR-AWS-REGION:YOUR-ACCOUNT-ID:quilt-alerts
```

**RDS Monitoring**
```bash
# Create CPU utilization alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "Quilt-RDS-CPU-High" \
  --alarm-description "RDS CPU utilization > 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/RDS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=DBInstanceIdentifier,Value=your-stack-name \
  --evaluation-periods 2 \
  --alarm-actions arn:aws:sns:YOUR-AWS-REGION:YOUR-ACCOUNT-ID:quilt-alerts
```

### Troubleshooting Common Issues

#### Issue 1: Deployment Fails with "InvalidParameterCombination"

**Symptoms**: Terraform apply fails with database parameter errors

**Solution**:
```bash
# Check current RDS version
aws rds describe-db-instances --db-instance-identifier your-stack-name

# If PostgreSQL < 11.22, upgrade manually first
aws rds modify-db-instance \
  --db-instance-identifier your-stack-name \
  --engine-version 11.22 \
  --apply-immediately

# Wait for upgrade to complete, then retry Terraform
```

#### Issue 2: ElasticSearch Domain Update Fails

**Symptoms**: "ValidationException: A change/update is in progress"

**Solution**:
```bash
# Check domain status
aws es describe-elasticsearch-domain --domain-name your-stack-name

# Wait for current operation to complete (check Processing field)
# Then retry Terraform apply
```

#### Issue 3: SSL Certificate Validation Stuck

**Symptoms**: Certificate remains in "Pending Validation" status

**Solution**:
```bash
# Check DNS validation records
aws acm describe-certificate --certificate-arn your-cert-arn

# Verify DNS records are correctly added to your domain
# Use DNS lookup tools to confirm propagation
dig _validation-record.data.YOUR-COMPANY.com CNAME
```

### Security Best Practices

#### Access Control
1. **Use IAM roles** instead of access keys where possible
2. **Enable MFA** for all administrative accounts
3. **Rotate credentials** regularly (quarterly)
4. **Use least privilege** principle for all permissions

#### Network Security
1. **Use internal ALB** for VPN-only access when possible
2. **Configure WAF** with appropriate geofencing
3. **Enable VPC Flow Logs** for network monitoring
4. **Use private subnets** for all internal services

#### Data Protection
1. **Enable encryption at rest** for all storage services
2. **Use SSL/TLS** for all data in transit
3. **Configure CloudTrail** for audit logging
4. **Enable GuardDuty** for threat detection

### Cost Optimization

#### Regular Cost Reviews
```bash
# Check monthly costs by service
aws ce get-cost-and-usage \
  --time-period Start=2023-11-01,End=2023-12-01 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# Identify optimization opportunities
# - Unused EBS volumes
# - Over-provisioned instances
# - Unnecessary data transfer
```

#### Optimization Strategies
1. **Use Reserved Instances** for production workloads
2. **Right-size instances** based on actual usage
3. **Implement lifecycle policies** for S3 storage
4. **Use Spot Instances** for non-critical workloads where applicable

### Support and Escalation

#### Internal Escalation Path
1. **Level 1**: Cloud team member (daily operations)
2. **Level 2**: Senior cloud engineer (scaling, troubleshooting)
3. **Level 3**: Cloud architect (design changes, major issues)

#### External Support
1. **Quilt Support**: Contact your account manager for application issues
2. **AWS Support**: Use your AWS support plan for infrastructure issues
3. **Community**: GitHub issues for module-related problems

#### Emergency Contacts
- **Cloud Team Lead**: [contact information]
- **On-call Engineer**: [contact information]
- **Quilt Account Manager**: [contact information]

## Prerequisites

> **📖 Additional Documentation**: For comprehensive enterprise installation guidance, refer to the official documentation at [docs.quilt.bio](https://docs.quilt.bio). This Terraform module complements the standard installation process with Infrastructure as Code automation.

### Required Tools
- **[Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)** >= 1.5.0
- **AWS CLI** >= 2.0 configured with appropriate permissions
- **Git** for version control and configuration management
- **jq** (optional) for JSON processing in automation scripts

### Required Resources

#### CloudFormation Template
Quilt provides Terraform-compatible CloudFormation templates via email:
- **Initial Installation**: Template delivered in your installation welcome email from Quilt
- **Platform Updates**: Updated templates sent regularly via platform update emails
- **Template Location**: Save the template as `quilt-template.yml` in your project directory
- **Version Management**: Always use the latest template version for updates and security patches
- **Template Validation**: Verify template integrity before deployment

#### AWS Infrastructure Requirements
- **AWS Account** with administrative permissions or specific IAM policies (see [AWS Permissions](#aws-permissions))
- **AWS Region** selection based on data residency and compliance requirements
- **SSL Certificate** in AWS Certificate Manager for HTTPS access
- **Domain Name** with DNS control for certificate validation and CNAME setup
- **VPC Planning** (if using existing VPC) with proper subnet architecture

#### Network Requirements

**For Internet-Facing Deployments:**
- Public subnets in at least 2 Availability Zones for load balancer
- Private subnets in at least 2 Availability Zones for application services
- Isolated subnets in at least 2 Availability Zones for database and search
- Internet Gateway for public subnet access
- NAT Gateways for private subnet internet access

**For Internal/VPN-Only Deployments:**
- Private subnets in at least 2 Availability Zones for application services and load balancer
- Isolated subnets in at least 2 Availability Zones for database and search
- VPC Endpoints for AWS service access (S3, ECR, CloudWatch, etc.)
- VPN or Direct Connect for user access

**Security Groups:**
- Application Load Balancer security group (port 443 from users)
- Application services security group (port 80 from ALB)
- Database security group (port 5432 from application)
- ElasticSearch security group (port 443 from application)

#### Capacity Planning

**Minimum Requirements:**
- **Database**: db.t3.small (2 vCPU, 2GB RAM) for development
- **ElasticSearch**: 1x m5.large.elasticsearch (2 vCPU, 8GB RAM, 512GB storage) for development
- **Application**: ECS Fargate tasks (0.5 vCPU, 1GB RAM per task)

**Production Recommendations:**
- **Database**: db.t3.medium or larger (2+ vCPU, 4+ GB RAM) with Multi-AZ
- **ElasticSearch**: 2x m5.xlarge.elasticsearch (4 vCPU, 16GB RAM, 1TB+ storage) with zone awareness
- **Application**: Multiple ECS Fargate tasks across availability zones

**Storage Considerations:**
- **Database Storage**: 100GB minimum, auto-scaling enabled
- **ElasticSearch Storage**: Size based on data volume (see [ElasticSearch Configuration](#elasticsearch-configuration))
- **Application Logs**: CloudWatch Logs with appropriate retention policies

### AWS Permissions

#### Required IAM Permissions
The deploying user or role needs the following AWS permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "rds:*",
        "es:*",
        "ecs:*",
        "elbv2:*",
        "elasticloadbalancing:*",
        "cloudformation:*",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:PassRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:CreateInstanceProfile",
        "iam:DeleteInstanceProfile",
        "iam:AddRoleToInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile",
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:GetBucketLocation",
        "s3:GetBucketVersioning",
        "s3:PutBucketVersioning",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "cloudwatch:*",
        "logs:*",
        "route53:*",
        "acm:*",
        "secretsmanager:*",
        "kms:*"
      ],
      "Resource": "*"
    }
  ]
}
```

#### Service-Linked Roles
Ensure the following AWS service-linked roles exist (created automatically if missing):
- `AWSServiceRoleForElasticLoadBalancing`
- `AWSServiceRoleForECS`
- `AWSServiceRoleForRDS`
- `AWSServiceRoleForElasticsearch`

### Security Considerations

#### Network Security
- **VPC Flow Logs**: Enable for network monitoring and security analysis
- **Security Groups**: Follow principle of least privilege
- **NACLs**: Additional layer of network security (optional)
- **WAF**: Web Application Firewall for additional protection (configured in CloudFormation)

#### Data Protection
- **Encryption at Rest**: Enabled for RDS, ElasticSearch, and S3
- **Encryption in Transit**: TLS 1.2+ for all communications
- **Key Management**: AWS KMS for encryption key management
- **Backup Encryption**: All backups encrypted with KMS

#### Access Control
- **IAM Roles**: Use IAM roles instead of access keys where possible
- **MFA**: Multi-factor authentication for administrative access
- **Audit Logging**: CloudTrail enabled for all API calls
- **Monitoring**: CloudWatch and GuardDuty for security monitoring

### Compliance Considerations

#### Data Residency
- Choose AWS region based on data residency requirements
- Consider AWS Local Zones for specific geographic requirements
- Review AWS compliance certifications for your region

#### Regulatory Compliance
- **SOC 2**: AWS infrastructure is SOC 2 compliant
- **GDPR**: Configure data retention and deletion policies
- **HIPAA**: Use HIPAA-eligible AWS services if handling PHI
- **FedRAMP**: Use FedRAMP authorized regions if required

### Monitoring and Observability

#### Required Monitoring
- **CloudWatch Metrics**: Infrastructure and application metrics
- **CloudWatch Logs**: Application and infrastructure logs
- **CloudWatch Alarms**: Proactive alerting for issues
- **AWS X-Ray**: Distributed tracing (optional)

#### Recommended Monitoring
- **AWS Config**: Configuration compliance monitoring
- **AWS GuardDuty**: Threat detection
- **AWS Security Hub**: Centralized security findings
- **AWS Systems Manager**: Patch management and compliance

## Quick Start

### 1. Create Your Project Directory

Your project structure should look like this:

```
quilt_stack/
├── main.tf
├── variables.tf          # Optional: for sensitive variables
├── terraform.tfvars      # Optional: for configuration values
└── my-company.yml        # Your CloudFormation template
```

Use [examples/main.tf](examples/main.tf) as a starting point for your main.tf.

> **It is neither necessary nor recommended to modify any module in this repository.**
> All supported customization is possible with arguments to `module.quilt`.

### 2. Basic Configuration

Here's a minimal configuration:

```hcl
provider "aws" {
  region              = "YOUR-AWS-REGION"
  allowed_account_ids = ["YOUR-ACCOUNT-ID"]
  default_tags {
    tags = {
      Environment = "production"
      Project     = "quilt"
    }
  }
}

terraform {
  backend "s3" {
    bucket = "YOUR-TERRAFORM-STATE-BUCKET"
    key    = "quilt/terraform.tfstate"
    region = "YOUR-AWS-REGION"
  }
}

locals {
  name            = "quilt-prod"
  build_file_path = "./quilt-template.yml"
  quilt_web_host  = "quilt.yourcompany.com"
}

module "quilt" {
  source = "github.com/quiltdata/iac//modules/quilt?ref=1.3.0"

  name          = local.name
  template_file = local.build_file_path
  
  internal       = false
  create_new_vpc = true
  cidr           = "10.0.0.0/16"

  parameters = {
    AdminEmail        = "admin@YOUR-COMPANY.com"
    CertificateArnELB = "arn:aws:acm:YOUR-AWS-REGION:YOUR-ACCOUNT-ID:certificate/YOUR-CERT-ID"
    QuiltWebHost      = local.quilt_web_host
    PasswordAuth      = "Enabled"
    Qurator          = "Enabled"
  }
}
```

### 3. Deploy

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

## ElasticSearch Configuration

**This section addresses ElasticSearch EBS volume specifications and sizing.**

### Understanding ElasticSearch Storage Requirements

Your primary consideration is the **total data node disk size**. Calculate your storage needs using:

1. **Source data size**: Average document size × total number of documents
2. **AWS formula**: `Source data × (1 + number of replicas) × 1.45 = minimum storage requirement`
3. **Production multiplier**: For production with 1 replica, multiply source data by 3 (rounded up from 2.9)

### ElasticSearch Sizing Configurations

#### Small (Development/Testing)
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

#### Medium (Default Production)
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

#### Large (High Volume)
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

#### X-Large (Enterprise)
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

### ElasticSearch Volume Types

| Volume Type | Use Case | IOPS | Throughput | Cost |
|-------------|----------|------|------------|------|
| `gp2` | General purpose, baseline performance | 3 IOPS/GiB (min 100, max 16,000) | Up to 250 MiB/s | Lower |
| `gp3` | General purpose, configurable performance | 3,000 baseline, up to 16,000 | 125 MiB/s baseline, up to 1,000 MiB/s | Optimized |
| `io1` | High IOPS, consistent performance | Up to 64,000 | Up to 1,000 MiB/s | Higher |

### Scaling ElasticSearch Storage

**Important**: Resizing existing domains is supported but requires time and may reduce quality of service during the blue/green update. Plan for growth in your initial sizing.

To increase storage:

1. Update `search_volume_size` in your configuration
2. Run `terraform plan` to verify changes
3. Run `terraform apply` during a maintenance window
4. Monitor the domain during the update process

| Argument           | `internal = true` (private ALB for VPN)       | `internal = false` (internet-facing ALB) |
|--------------------|-----------------------------------------------|------------------------------------------|
| intra_subnets      | Isolated subnets (no NAT) for `db` & `search` | "                                        |
| private_subnets    | For Quilt services                            | "                                        |
| public_subnets     | n/a                                           | For IGW, ALB                             |
| user_subnets       | For ALB (when `create_new_vpc = false`)       | n/a                                      |
| user_security_group| For ALB access                                | n/a                                      |
| api_endpoint       | For API Gateway when `create_new_vpc = false` | n/a                                      |

#### Example VPC Endpoint for API Gateway
This endpoint must be reachable by your VPN clients.

```hcl
resource "aws_vpc_endpoint" "api_gateway_endpoint" {
  vpc_id              = ""
  service_name        = "com.amazonaws.${var.region}.execute-api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnet_ids
  security_group_ids  = ""
  private_dns_enabled = true
}
```

### Profile
You may wish to set a specific AWS profile before executing `terraform`
commands.

```sh
export AWS_PROFILE=your-aws-profile
```
> We discourage the use of `provider.profile` in team environments
> where profile names may differ across users and machines.

### Rightsize your search domain
Your primary consideration is the _total_ data node disk size.
If you multiply your average document size (likely a function of the number of
[deep-indexed](https://docs.quiltdata.com/catalog/searchquery#indexing) documents
and your depth limit) by the total number of documents that will give you "Source data" below.

> Each shallow-indexed document requires a constant number of bytes on the order
> of 1kB.

Follow AWS's documentation on [Sizing Search Domains](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/sizing-domains.html)
and note the following simplified formula:

> `Source data * (1 + number of replicas) * 1.45` = minimum storage requirement

For a production Quilt deployment the number of replicas will be 1, so multiplying
"Source data" by 3 (2.9 rounded up) is a fair starting point. Be sure to account
for growth in your Quilt buckets. "Live" resizing of existing domains is supported
but requires time and may reduce quality of service during the blue/green update.

Below are known-good search sizes that you can set on the `quilt` module.

#### Small
```hcl
search_dedicated_master_enabled = false
search_zone_awareness_enabled = false
search_instance_count = 1
search_instance_type = "m5.large.elasticsearch"
search_volume_size = 512
```

#### Medium (default)
```hcl
search_dedicated_master_enabled = true
search_zone_awareness_enabled = true
search_instance_count = 2
search_instance_type = "m5.xlarge.elasticsearch"
search_volume_size = 1024
```

#### Large
```hcl
search_dedicated_master_enabled = true
search_zone_awareness_enabled = true
search_instance_count = 2
search_instance_type = "m5.xlarge.elasticsearch"
search_volume_size = 2*1024
search_volume_type = "gp3"
```

#### X-Large
```hcl
search_dedicated_master_enabled = true
search_zone_awareness_enabled = true
search_instance_count = 2
search_instance_type = "m5.2xlarge.elasticsearch"
search_volume_size = 3*1024
search_volume_type = "gp3"
search_volume_iops = 16000
```

#### XX-Large
```hcl
search_dedicated_master_enabled = true
search_zone_awareness_enabled = true
search_instance_count = 2
search_instance_type = "m5.4xlarge.elasticsearch"
search_volume_size = 6*1024
search_volume_type = "gp3"
search_volume_iops = 18750
```

#### XXX-Large
```hcl
search_dedicated_master_enabled = true
search_zone_awareness_enabled = true
search_instance_count = 2
search_instance_type = "m5.12xlarge.elasticsearch"
search_volume_size = 18*1024
search_volume_type = "gp3"
search_volume_iops = 40000
search_volume_throughput = 1187
```

#### XXXX-Large
```hcl
search_dedicated_master_enabled = true
search_zone_awareness_enabled = true
search_instance_count = 4
search_instance_type = "m5.12xlarge.elasticsearch"
search_volume_size = 18*1024
search_volume_type = "gp3"
search_volume_iops = 40000
search_volume_throughput = 1187
```

## Deploying and updating Quilt
As a rule, `terraform apply` is sufficient to both deploy and update Quilt.

### Verify the plan
Before calling `apply` read `terraform plan` carefully to ensure that it does
not inadvertently destroy and recreate the stack. The following modifications
are known to cause issues (see [examples/main.tf](examples/main.tf) for context).

* Modifying `local.name`.
* Modifying `local.build_file_path`.
* Modifying `quilt.template_file`.

And for older versions of Terraform and customers whose usage predates the present
module:

* Modifying `template_url=` (in older versions of Terraform).

# Terraform cheat sheet

## Initialize
```sh
terraform init
```

If for instance you change the provider pinning you may need to `-upgrade`:

```sh
terraform init -upgrade
```

## Lint
```
terraform fmt
```

## Validate

```
terraform validate
```

## Plan
```
terraform plan -out tfplan
```

## Apply
If the plan is what you want:
```
terraform apply tfplan
```

## Output sensitive values
Sensitive values must be named in order to display on the command line:
```
terraform output admin_password
```

## State

### Inspect
```
terraform state list
```

Or, to show a specific entity:
```
terraform state show 'thing.from.list'
```

### Refresh
```
terraform refresh
```

## Destroy
```
terraform destroy
```

## Routine updates
1. Start with a clean commit of the previous apply in your Quilt Terraform folder
(nothing uncommitted).
1. In your `main.tf` file, do the following:
    1. Update the YAML file at `local.build_file_path` with the new CloudFormation
    template that you received from Quilt.
        > Do not change the value of `build_file_path`, as noted [above](#verify-the-plan).
    1. Update the `quilt.source=` pin to the newest
    [tag](https://github.com/quiltdata/iac/tags)
    from the present repository.
1. [Initialize](#initialize).
1. [Plan](#plan).
1. [Verify the plan](#verify-the-plan).
1. [Apply](#apply).
1. Commit the [appropriate files](#check-these-files-in).

## Git version control
### Check these files in
* `*.tf`
* `terraform.lock.hcl`
* Your Quilt `build_file`

### Ignore these files
You may wish to create a `.gitignore` file similar to the following:
```
.terraform
tfplan
```

> We recommend that you use
> [remote state](https://developer.hashicorp.com/terraform/language/state/remote)
> so that no passwords are checked into version control.

# Known issues

##  invalid error message

Due to how Terraform evaluates (or fails to evaluate) arguments in a precondition
(e.g. `user_security_group = aws_security_group.lb_security_group.id`) you may
see the following error message. Provide a static string instead of a dynamic value.

```
│   27:     condition     = !local.configuration_error
│     ├────────────────
│     │ local.configuration_error is true
│
│ This check failed, but has an invalid error message as described in the other accompanying messages.
```

Provide a static string instead (e.g. `user_security_group = "123"`) and you should
receive a more informative message similar to the following:

```
│ In order to use an existing VPC (create_new_vpc == false) correct the following attributes:
│ ❌ api_endpoint (required if var.internal == true, else must be null)
│ ✅ create_new_vpc == false
│ ✅ intra_subnets (required)
│ ✅ private_subnets (required)
│ ❌ public_subnets (required if var.internal == false, else must be null)
│ ✅ user_security_group (required)
│ ❌ user_subnets (required if var.internal == true and var.create_new_vpc == false, else must be null)
│ ✅ vpc_id (required)
```

## RDS InvalidParameterCombination

> ```
> InvalidParameterCombination: Cannot upgrade postgres from 11.X to 15.Y
> ```

Later versions of the current module set database `auto_minor_version_upgrade = false`.
As a result some users may find their Quilt RDS instance on Postgres 11.19.
These users should _first upgrade to 11.22 using the AWS Console_ and then apply
a recent version of the present module, which will upgrade Postgres to 15.5.

Users who have auto-minor-version-upgraded to 11.22 can apply the present module
to automatically upgrade to 15.5 (without any manual steps).

Engine version changes are applied _during the next maintenance window_,
therefore you may not see them immediately in AWS Console.

## Elasticsearch ValidationException
> ```
> Error: updating Elasticsearch Domain (arn:aws:es:foo:bar/baz) config:
> ValidationException: A change/update is in progress. Please wait for it to
> complete before requesting another change.
> ```

If you encounter the above error we suggest that you use the latest version of the
current repo which no longer uses an `auto_tune_options` configuration block in
the `search` module. We further recommend that you only use
[search instances that support Auto-Tune](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/supported-instance-types.html)
as the AWS service may automatically enable Auto-Tune without cause and without warning,
leading to search domains that are difficult to upgrade.

Some users have overcome the above error by pinning the provider to 5.20.0 as shown
below but this is not recommended given that 5.20.0 is an older version.

```hcl
provider "aws" {
    version = "= 5.20.0"
}
```

# References
1. [Terraform: AWS Provider Tutorial](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-build)
1. [Terraform: Basic CLI Features](https://developer.hashicorp.com/terraform/cli/commands)

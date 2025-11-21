# External IAM Pattern Example

This example demonstrates deploying Quilt infrastructure using the **external IAM pattern** where IAM resources are managed in a separate CloudFormation stack.

## Overview

The external IAM pattern separates IAM roles and policies from application infrastructure, enabling:
- Independent IAM management by security teams
- Different deployment lifecycles for IAM vs. application
- Stricter governance controls over IAM resources
- Separate permissions for IAM deployment vs. application deployment

## Architecture

```
┌──────────────────────────────────┐
│  IAM CloudFormation Stack        │
│  (deployed by security team)     │
│                                   │
│  - 24 IAM Roles                  │
│  - 8 IAM Managed Policies        │
│  - 32 CloudFormation Outputs     │
└──────────────────────────────────┘
              │
              │ ARNs via CloudFormation Exports
              ▼
┌──────────────────────────────────┐
│  Application CloudFormation Stack │
│  (deployed by app team)          │
│                                   │
│  - Lambda Functions              │
│  - ECS Services                  │
│  - API Gateway                   │
│  - References IAM ARNs           │
└──────────────────────────────────┘
```

## Prerequisites

### 1. Obtain Quilt CloudFormation Templates

Get the pre-split templates from Quilt:
- `quilt-iam.yaml` - IAM resources only
- `quilt-app.yaml` - Application resources with IAM parameters

Or split an existing monolithic template using Quilt's split script.

### 2. Upload Templates to S3

```bash
# Create S3 bucket (if needed)
aws s3 mb s3://my-quilt-templates

# Upload IAM template
aws s3 cp quilt-iam.yaml s3://my-quilt-templates/quilt-iam.yaml

# Upload application template
aws s3 cp quilt-app.yaml s3://my-quilt-templates/quilt-app.yaml
```

### 3. Prepare Terraform Configuration

Copy this example and customize the variables.

## Configuration

### main.tf

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Deploy Quilt infrastructure with external IAM pattern
module "quilt" {
  source = "../../modules/quilt"

  name     = var.name
  internal = var.internal

  # Enable external IAM pattern by providing IAM template URL
  iam_template_url = "https://${var.s3_bucket}.s3.${var.region}.amazonaws.com/quilt-iam.yaml"

  # Optional: override IAM stack name (defaults to "{name}-iam")
  # iam_stack_name = "custom-iam-stack-name"

  # Optional: IAM-specific tags
  iam_tags = {
    ManagedBy = "SecurityTeam"
    Purpose   = "IAM"
  }

  # Application template file (local path to upload to S3)
  template_file = var.template_file

  # CloudFormation parameters for application stack
  parameters = var.parameters

  # VPC configuration
  create_new_vpc = true
  cidr           = "10.0.0.0/16"

  # Database configuration
  db_instance_class      = "db.t3.medium"
  db_multi_az            = true
  db_deletion_protection = true

  # ElasticSearch configuration
  search_instance_count = 2
  search_instance_type  = "m5.xlarge.elasticsearch"
}
```

### variables.tf

```hcl
variable "name" {
  type        = string
  description = "Deployment name (max 20 chars, lowercase alphanumeric and hyphens)"
}

variable "region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region for deployment"
}

variable "s3_bucket" {
  type        = string
  description = "S3 bucket containing CloudFormation templates"
}

variable "internal" {
  type        = bool
  default     = false
  description = "Whether to create internal load balancer"
}

variable "template_file" {
  type        = string
  description = "Local path to application CloudFormation template (quilt-app.yaml)"
}

variable "parameters" {
  type        = map(any)
  default     = {}
  description = "Additional CloudFormation parameters for application stack"
}
```

### terraform.tfvars

```hcl
name          = "quilt-prod"
region        = "us-east-1"
s3_bucket     = "my-quilt-templates"
internal      = false
template_file = "./quilt-app.yaml"

parameters = {
  # Your application-specific parameters
}
```

### outputs.tf

```hcl
output "vpc_id" {
  description = "VPC ID"
  value       = module.quilt.vpc.vpc_id
}

output "stack_id" {
  description = "Application CloudFormation stack ID"
  value       = module.quilt.stack.id
}

output "iam_stack_id" {
  description = "IAM CloudFormation stack ID"
  value       = module.quilt.iam_stack_id
}

output "iam_role_arns" {
  description = "Map of IAM role ARNs"
  value       = module.quilt.iam_role_arns
  sensitive   = true
}

output "iam_policy_arns" {
  description = "Map of IAM policy ARNs"
  value       = module.quilt.iam_policy_arns
  sensitive   = true
}
```

## Deployment

### Initialize Terraform

```bash
terraform init
```

### Review Plan

```bash
terraform plan -out=tfplan
```

Review the plan carefully. You should see:
1. IAM module resources (CloudFormation stack)
2. Data source to query IAM stack outputs
3. Quilt module resources with IAM parameters

### Apply Configuration

```bash
terraform apply tfplan
```

Deployment order (handled automatically by Terraform):
1. VPC, DB, ElasticSearch infrastructure
2. IAM CloudFormation stack
3. Application CloudFormation stack (with IAM parameters)

Expected duration: 15-20 minutes

### Verify Deployment

```bash
# Check IAM stack
aws cloudformation describe-stacks --stack-name quilt-prod-iam

# Check application stack
aws cloudformation describe-stacks --stack-name quilt-prod

# View IAM outputs
terraform output iam_role_arns
```

## Updates

### IAM Updates

When IAM policies need updating:

1. Update `quilt-iam.yaml` template
2. Upload to S3:
   ```bash
   aws s3 cp quilt-iam.yaml s3://my-quilt-templates/quilt-iam.yaml
   ```
3. Run Terraform:
   ```bash
   terraform plan
   terraform apply
   ```

Terraform will update the IAM stack. If ARNs change (role replacement), the application stack will also update.

### Application Updates

When application resources need updating:

1. Update `quilt-app.yaml` template
2. Run Terraform:
   ```bash
   terraform plan
   terraform apply
   ```

IAM stack remains unchanged if only application changes.

## Teardown

```bash
terraform destroy
```

Terraform automatically destroys resources in correct order:
1. Application stack (removed first)
2. IAM stack (removed second)
3. Infrastructure resources

## Comparison with Inline IAM

| Aspect | External IAM | Inline IAM |
|--------|--------------|------------|
| **Stacks** | 2 (IAM + App) | 1 (Monolithic) |
| **IAM Control** | Separate governance | Same as app |
| **Deployment** | More complex | Simpler |
| **Updates** | Independent IAM updates | Coupled updates |
| **Permissions** | Separate IAM permissions | Single permission set |
| **Best For** | Enterprise, strict governance | Standard deployments |

## Troubleshooting

### IAM Stack Creation Failed

**Problem**: IAM stack fails to create

**Solutions**:
- Check IAM template is valid: `aws cloudformation validate-template --template-url https://...`
- Verify IAM permissions to create roles/policies
- Check for naming conflicts with existing IAM resources
- Review CloudFormation stack events: `aws cloudformation describe-stack-events --stack-name quilt-prod-iam`

### Application Stack Missing IAM Parameters

**Problem**: Application stack complains about missing parameters

**Solutions**:
- Verify IAM stack deployed successfully: `terraform state show module.quilt.module.iam[0].aws_cloudformation_stack.iam`
- Check IAM stack has all 32 outputs: `aws cloudformation describe-stacks --stack-name quilt-prod-iam --query 'Stacks[0].Outputs'`
- Ensure application template expects IAM parameters (using split template)

### Cannot Delete IAM Stack

**Problem**: CloudFormation error: "Export in use by another stack"

**Solutions**:
- Delete application stack first: `terraform destroy -target=module.quilt.aws_cloudformation_stack.stack`
- Then delete IAM stack: `terraform destroy -target=module.quilt.module.iam[0]`
- Or use full destroy: `terraform destroy` (handles order automatically)

## Migration from Inline IAM

If migrating from inline IAM to external IAM:

1. **Split existing template** using Quilt's split script
2. **Deploy IAM stack separately** first
3. **Update application template** to use parameters instead of inline IAM
4. **Update Terraform config** to set `iam_template_url`
5. **Plan carefully** - may require stack replacement
6. **Schedule maintenance window** - expect downtime during migration

**Recommendation**: Only migrate if IAM governance requirements mandate it. Inline IAM is simpler for most use cases.

## Additional Resources

- [Quilt Module Documentation](../../modules/quilt/README.md)
- [IAM Module Documentation](../../modules/iam/README.md)
- [IAM Module Specification](../../spec/91-externalized-iam/03-spec-iam-module.md)
- [Integration Specification](../../spec/91-externalized-iam/05-spec-integration.md)

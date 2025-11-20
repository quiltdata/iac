# Inline IAM Pattern Example (Default)

This example demonstrates deploying Quilt infrastructure using the **inline IAM pattern** where IAM resources are included in the same CloudFormation stack as application resources.

## Overview

The inline IAM pattern is the **default and simplest** deployment method where all resources (IAM, Lambda, ECS, etc.) are managed in a single CloudFormation stack.

## When to Use Inline IAM

**Use inline IAM (this pattern) when:**
- You want simple, straightforward deployment
- IAM and application can be managed by the same team
- You don't have strict IAM separation requirements
- You prefer fewer moving parts and dependencies

**Use external IAM when:**
- Organization requires separate IAM governance
- Security team manages IAM independently
- Compliance mandates IAM separation

## Architecture

```
┌────────────────────────────────────────────┐
│  Single CloudFormation Stack              │
│                                            │
│  IAM Resources (inline):                  │
│  - 24 IAM Roles                           │
│  - 8 IAM Managed Policies                 │
│                                            │
│  Application Resources:                   │
│  - Lambda Functions (using IAM roles)     │
│  - ECS Services (using IAM roles)         │
│  - API Gateway (using IAM roles)          │
│  - All resources in one stack             │
└────────────────────────────────────────────┘
```

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

# Deploy Quilt infrastructure with inline IAM pattern (default)
module "quilt" {
  source = "../../modules/quilt"

  name     = var.name
  internal = var.internal

  # NOTE: iam_template_url is NOT set (null)
  # This triggers inline IAM pattern (default behavior)

  # Monolithic CloudFormation template (includes IAM)
  template_file = var.template_file

  # CloudFormation parameters
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

variable "internal" {
  type        = bool
  default     = false
  description = "Whether to create internal load balancer"
}

variable "template_file" {
  type        = string
  description = "Local path to monolithic CloudFormation template (includes IAM)"
}

variable "parameters" {
  type        = map(any)
  default     = {}
  description = "CloudFormation parameters"
}
```

### terraform.tfvars

```hcl
name          = "quilt-dev"
region        = "us-east-1"
internal      = false
template_file = "./quilt.yaml"  # Monolithic template

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
  description = "CloudFormation stack ID"
  value       = module.quilt.stack.id
}

output "stack_outputs" {
  description = "All CloudFormation stack outputs"
  value       = module.quilt.stack.outputs
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

You should see:
1. VPC, DB, ElasticSearch infrastructure resources
2. S3 bucket for CloudFormation template
3. Single CloudFormation stack (with inline IAM)
4. **No IAM module** (confirms inline pattern)

### Apply Configuration

```bash
terraform apply tfplan
```

Deployment order (handled automatically):
1. VPC, DB, ElasticSearch infrastructure
2. CloudFormation stack with all resources

Expected duration: 15-20 minutes

### Verify Deployment

```bash
# Check stack
aws cloudformation describe-stacks --stack-name quilt-dev

# View outputs
terraform output
```

## Updates

When any resources need updating:

1. Update `quilt.yaml` template (or Terraform variables)
2. Run Terraform:
   ```bash
   terraform plan
   terraform apply
   ```

All resources update in a single stack operation.

## Teardown

```bash
terraform destroy
```

Single stack deletion removes all resources.

## Comparison with External IAM

| Aspect | Inline IAM (This) | External IAM |
|--------|-------------------|--------------|
| **Simplicity** | ✅ Simpler | More complex |
| **Stacks** | 1 | 2 |
| **IAM Control** | Same as app | Separate |
| **Deployment Steps** | Fewer | More |
| **Dependencies** | None | IAM stack first |
| **Updates** | Coupled | Independent |
| **Best For** | Most deployments | Enterprise governance |

## Key Differences from External IAM

### What You DON'T Need

- Separate IAM template
- `iam_template_url` variable
- IAM module
- IAM stack management
- CloudFormation export dependencies

### What You DO NEED

- Monolithic CloudFormation template (includes IAM)
- IAM permissions to create roles/policies
- `CAPABILITY_NAMED_IAM` capability (automatically set)

## Troubleshooting

### Stack Creation Failed

**Problem**: CloudFormation stack fails

**Solutions**:
- Review CloudFormation events: `aws cloudformation describe-stack-events --stack-name quilt-dev`
- Check IAM permissions for deployer
- Verify template syntax: `aws cloudformation validate-template --template-body file://quilt.yaml`

### IAM Resource Creation Failed

**Problem**: IAM roles or policies fail to create

**Solutions**:
- Check IAM permissions
- Verify no naming conflicts with existing IAM resources
- Check IAM service quotas
- Review IAM resource definitions in template

## Migration to External IAM

If you need to migrate to external IAM:

1. **Split template** using Quilt's split script
2. **Upload both templates** to S3
3. **Update Terraform config** to add `iam_template_url`
4. **Plan migration** - may require stack replacement
5. **Schedule maintenance** - expect potential downtime

**Note**: Migration is disruptive. Only migrate if organizational requirements mandate it.

## Additional Resources

- [Quilt Module Documentation](../../modules/quilt/README.md)
- [External IAM Example](../external-iam/README.md)
- [Requirements Document](../../spec/91-externalized-iam/01-requirements.md)

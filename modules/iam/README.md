# IAM Module

This Terraform module deploys Quilt IAM resources in a separate CloudFormation stack, enabling enterprise customers to manage IAM roles and policies independently from application infrastructure.

## Overview

The IAM module is designed to work with **Quilt-provided CloudFormation templates** that have been pre-split using Quilt's IAM split tooling. It creates a CloudFormation stack containing 24 IAM roles and 8 IAM managed policies, outputting their ARNs for consumption by the application stack.

## When to Use This Module

**Use the IAM module when:**
- Your organization requires separation of IAM management from application deployment
- Security teams need independent control over IAM resources
- You need to deploy IAM resources with different lifecycle or permissions than application resources
- Compliance requirements mandate separate IAM governance

**Use inline IAM (default) when:**
- You want simpler deployment with fewer moving parts
- IAM and application resources can be managed by the same team
- You don't have strict IAM separation requirements

## Usage

### Basic Usage

```hcl
module "iam" {
  source = "./modules/iam"

  name         = "my-quilt-deployment"
  template_url = "https://my-bucket.s3.us-east-1.amazonaws.com/quilt-iam.yaml"
}
```

### With Custom Stack Name

```hcl
module "iam" {
  source = "./modules/iam"

  name           = "my-quilt-deployment"
  template_url   = "https://my-bucket.s3.us-east-1.amazonaws.com/quilt-iam.yaml"
  iam_stack_name = "custom-iam-stack-name"
}
```

### With Parameters and Tags

```hcl
module "iam" {
  source = "./modules/iam"

  name         = "my-quilt-deployment"
  template_url = "https://my-bucket.s3.us-east-1.amazonaws.com/quilt-iam.yaml"

  parameters = {
    SomeParameter = "value"
  }

  tags = {
    Environment = "production"
    Owner       = "security-team"
  }
}
```

## Requirements

### Template Requirements

The CloudFormation template must be a Quilt-provided IAM template that:
- Contains all 24 IAM roles defined in Quilt's config.yaml
- Contains all 8 IAM managed policies defined in Quilt's config.yaml
- Outputs ARNs for all 32 resources with specific naming convention
- Does not reference application resources (queues, buckets, Lambda functions)

### Prerequisites

1. **Quilt IAM Template**: Obtain the pre-split IAM CloudFormation template from Quilt
2. **S3 Upload**: Upload the template to an S3 bucket accessible to Terraform
3. **IAM Permissions**: Ensure deployer has permissions to create IAM roles and policies

## Module Interface

### Inputs

| Name | Type | Default | Required | Description |
|------|------|---------|----------|-------------|
| `name` | `string` | - | Yes | Base name for the IAM stack (max 20 chars) |
| `template_url` | `string` | - | Yes | S3 HTTPS URL of Quilt IAM CloudFormation template |
| `iam_stack_name` | `string` | `null` | No | Override default stack name ({name}-iam) |
| `parameters` | `map(string)` | `{}` | No | CloudFormation parameters for IAM stack |
| `tags` | `map(string)` | `{}` | No | Tags to apply to IAM stack |
| `capabilities` | `list(string)` | `["CAPABILITY_NAMED_IAM"]` | No | CloudFormation capabilities |

### Outputs

The module outputs 34 values:

#### Stack Metadata (2 outputs)
- `stack_id` - CloudFormation stack ID
- `stack_name` - CloudFormation stack name

#### IAM Role ARNs (24 outputs)
All role outputs follow the pattern `{RoleName}Arn`:
- `SearchHandlerRoleArn`
- `EsIngestRoleArn`
- `ManifestIndexerRoleArn`
- `AccessCountsRoleArn`
- `PkgEventsRoleArn`
- `DuckDBSelectLambdaRoleArn`
- `PkgPushRoleArn`
- `PackagerRoleArn`
- `AmazonECSTaskExecutionRoleArn`
- `ManagedUserRoleArn`
- `MigrationLambdaRoleArn`
- `TrackingCronRoleArn`
- `ApiRoleArn`
- `TimestampResourceHandlerRoleArn`
- `TabulatorRoleArn`
- `TabulatorOpenQueryRoleArn`
- `IcebergLambdaRoleArn`
- `T4BucketReadRoleArn`
- `T4BucketWriteRoleArn`
- `S3ProxyRoleArn`
- `S3LambdaRoleArn`
- `S3SNSToEventBridgeRoleArn`
- `S3HashLambdaRoleArn`
- `S3CopyLambdaRoleArn`

#### IAM Policy ARNs (8 outputs)
All policy outputs follow the pattern `{PolicyName}Arn`:
- `BucketReadPolicyArn`
- `BucketWritePolicyArn`
- `RegistryAssumeRolePolicyArn`
- `ManagedUserRoleBasePolicyArn`
- `UserAthenaNonManagedRolePolicyArn`
- `UserAthenaManagedRolePolicyArn`
- `TabulatorOpenQueryPolicyArn`
- `T4DefaultBucketReadPolicyArn`

## Integration with Quilt Module

The IAM module is designed to be consumed by the Quilt module:

```hcl
# Deploy IAM stack separately
module "iam" {
  source = "./modules/iam"

  name         = var.name
  template_url = var.iam_template_url
}

# Reference IAM outputs in application stack
module "quilt" {
  source = "./modules/quilt"

  name             = var.name
  iam_template_url = var.iam_template_url  # Triggers external IAM pattern

  # ... other configuration
}
```

The Quilt module will automatically:
1. Query the IAM stack outputs via data source
2. Transform ARNs to CloudFormation parameters
3. Pass parameters to application stack

## Resource Naming

- **Default Stack Name**: `{name}-iam`
- **CloudFormation Export Names**: `{stack_name}-{ResourceName}Arn`
- **IAM Resource Names**: Defined by CloudFormation template (typically `{stack_name}-{ResourceName}`)

## Important Notes

### Stack Dependencies

The IAM stack must be deployed **before** the application stack. The Quilt module handles this dependency automatically when both modules are used together.

### Stack Exports

The IAM stack creates CloudFormation exports for all outputs. This means:
- Exports are region-specific (deploy IAM stack in each region)
- Exports prevent stack deletion while imported by other stacks
- Export names must be unique within region/account

### Updates and Deletions

**IAM Stack Updates:**
- Policy changes typically update in-place with no downtime
- Resource name changes require replacement and may cause application disruption
- Always review Terraform plan before applying IAM updates

**Stack Deletion:**
- Application stack must be deleted before IAM stack
- Terraform handles dependency order automatically with `terraform destroy`
- Manual deletion requires reverse order (app first, then IAM)

### Version Compatibility

The module expects CloudFormation templates that match the resource list in Quilt's config.yaml. Ensure:
- Module version matches template version
- Template contains all expected outputs
- Output names follow exact naming convention

## Troubleshooting

### Error: "Template URL does not exist"
- Verify S3 bucket exists and template is uploaded
- Check IAM permissions to access S3 bucket
- Ensure template URL is correct HTTPS format

### Error: "Missing output: SearchHandlerRoleArn"
- Template does not match expected structure
- Ensure using Quilt-provided IAM template
- Check template was generated from correct config.yaml version

### Error: "Stack already exists"
- IAM stack with same name already deployed
- Use different `name` or `iam_stack_name`
- Delete existing stack if appropriate

### Error: "Export cannot be deleted as it is in use"
- Application stack still references IAM exports
- Delete application stack before IAM stack
- Use `terraform destroy` to handle dependencies automatically

## Related Documentation

- [Quilt Module Specification](../../spec/91-externalized-iam/04-spec-quilt-module.md)
- [IAM Module Specification](../../spec/91-externalized-iam/03-spec-iam-module.md)
- [Integration Specification](../../spec/91-externalized-iam/05-spec-integration.md)
- [config.yaml](../../spec/91-externalized-iam/config.yaml) - Source of truth for IAM resources

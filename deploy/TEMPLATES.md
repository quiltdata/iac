# CloudFormation Template Configuration

This document describes how the CloudFormation templates for the externalized IAM pattern are configured and generated.

## Overview

The Quilt infrastructure uses a split-stack architecture where IAM resources are separated from application resources to enable better security boundaries and independent management.

## Template Architecture

```
┌─────────────────────┐
│   IAM Stack         │
│  (quilt-iac-iam)    │
│                     │
│  - 2 IAM Roles      │
│  - 3 IAM Policies   │
│  - 5 Outputs        │
└──────┬──────────────┘
       │ (outputs: role/policy ARNs)
       ↓
┌─────────────────────┐
│  Application Stack  │
│   (quilt-iac)       │
│                     │
│  - All other IAM    │
│  - App resources    │
│  - Infrastructure   │
└─────────────────────┘
```

## Source Templates

### Location
- **Source template**: `../test/fixtures/stable.yaml` (monolithic CloudFormation template)
- **IAM template**: `../test/fixtures/stable-iam.yaml` (generated)
- **App template**: `../test/fixtures/stable-app.yaml` (generated)

### Split Configuration
Template splitting is controlled by: `~/GitHub/scripts/iam-split/config.yaml`

```yaml
extraction:
  roles:
    - ApiRole
    - TimestampResourceHandlerRole

  policies:
    - BucketReadPolicy
    - BucketWritePolicy
    - RegistryAssumeRolePolicy
```

## Generation Process

### Prerequisites
1. IAM split script: `~/GitHub/scripts/iam-split/split_iam.py`
2. Python 3.x with dependencies from `~/GitHub/scripts/iam-split/requirements.txt`

### Regenerating Templates

To regenerate the split templates after changes to the source:

```bash
cd ~/GitHub/scripts/iam-split

python3 split_iam.py \
  --input-file ~/GitHub/iac/test/fixtures/stable.yaml \
  --output-iam ~/GitHub/iac/test/fixtures/stable-iam.yaml \
  --output-app ~/GitHub/iac/test/fixtures/stable-app.yaml \
  --config config.yaml \
  --generate-report /tmp/iam-split-report.md \
  --verbose
```

### Validation

After regeneration, validate templates:

```bash
cd ~/GitHub/iac

# Validate IAM template
aws cloudformation validate-template \
  --template-body file://test/fixtures/stable-iam.yaml

# Validate app template
aws cloudformation validate-template \
  --template-body file://test/fixtures/stable-app.yaml
```

## Why Only 2 Roles + 3 Policies?

The IAM split is intentionally minimal due to **extensive circular dependencies** in the original monolithic template.

### Dependency Analysis

Most IAM roles cannot be extracted because they reference:

| Resource Type | Examples | Impact |
|---------------|----------|--------|
| **Buckets** | ServiceBucket, StatusReportsBucket, EsIngestBucket | Used in IAM policy Resource statements |
| **Queues** | IndexerQueue, EsIngestQueue, PkgEventsQueue | Used for SQS permissions |
| **Lambdas** | S3HashLambda, DuckDBSelectLambda, PkgCreate | Used for invoke permissions |
| **Other IAM Roles** | AmazonECSTaskExecutionRole | Used in AssumeRole policies |
| **Parameters** | CertificateArnELB, SearchDomainArn | Used in policy statements |

### Roles That Cannot Be Extracted

These roles remain in the app stack due to dependencies:

- `SearchHandlerRole` → references IndexerQueue, ManifestIndexerQueue
- `EsIngestRole` → references EsIngestBucket, EsIngestQueue
- `ManifestIndexerRole` → references EsIngestBucket, ManifestIndexerQueue
- `PkgEventsRole` → references PkgEventsQueue
- `DuckDBSelectLambdaRole` → references DuckDBSelectLambda, DuckDBSelectLambdaBucket
- `PkgPushRole` → references ServiceBucket, S3HashLambda, S3CopyLambda
- `PackagerRole` → references PackagerQueue, ServiceBucket
- `ManagedUserRole` → references AmazonECSTaskExecutionRole
- `T4BucketReadRole` → references AmazonECSTaskExecutionRole
- `TabulatorRole` → references TabulatorBucket
- `TabulatorOpenQueryRole` → references AmazonECSTaskExecutionRole
- `IcebergLambdaRole` → references IcebergBucket, IcebergLambdaQueue
- `S3ProxyRole` → references CertificateArnELB parameter
- And many others...

### Extracted Resources

Only these resources have **zero dependencies**:

**IAM Roles:**
1. `ApiRole` - API Gateway execution role
2. `TimestampResourceHandlerRole` - Custom resource handler

**IAM Policies:**
1. `BucketReadPolicy` - Generic S3 read permissions
2. `BucketWritePolicy` - Generic S3 write permissions
3. `RegistryAssumeRolePolicy` - Generic assume role policy

## Terraform Integration

The Terraform configuration at `templates/external-iam.tf.j2` orchestrates the deployment:

### IAM Stack Resource

```hcl
resource "aws_cloudformation_stack" "iam" {
  name = "${var.name}-iam"
  template_url = var.iam_template_url
  capabilities = ["CAPABILITY_IAM", "CAPABILITY_NAMED_IAM"]

  # No parameters - IAM template is self-contained

  tags = {
    Name        = "${var.name}-iam"
    Component   = "IAM"
    Environment = "{{ config.environment }}"
  }
}
```

### Application Stack Resource

```hcl
resource "aws_cloudformation_stack" "app" {
  name = var.name
  template_url = var.template_url
  depends_on = [aws_cloudformation_stack.iam]
  capabilities = ["CAPABILITY_IAM", "CAPABILITY_NAMED_IAM"]

  parameters = merge(
    {
      # Network, DNS, database, etc.
      VPC = var.vpc_id
      # ... other config parameters
    },
    # IAM role/policy ARNs from IAM stack outputs
    {
      for key, value in aws_cloudformation_stack.iam.outputs :
      key => value
    }
  )
}
```

### Parameter Flow

```
IAM Stack Outputs → Terraform → App Stack Parameters
─────────────────────────────────────────────────────
ApiRoleArn                    → ApiRole
TimestampResourceHandlerRoleArn → TimestampResourceHandlerRole
BucketReadPolicyArn          → BucketReadPolicy
BucketWritePolicyArn         → BucketWritePolicy
RegistryAssumeRolePolicyArn  → RegistryAssumeRolePolicy
```

## Deployment Order

1. **Upload templates** to S3 bucket
2. **Deploy IAM stack** first (no dependencies)
3. **Get IAM outputs** (role/policy ARNs)
4. **Deploy app stack** with IAM outputs as parameters

## Troubleshooting

### Template Validation Errors

**Error:** `Parameter values specified for a template which does not require them`
- **Cause:** Passing parameters to IAM template
- **Fix:** IAM stack should have no `parameters` block in Terraform

**Error:** `instance of Fn::Sub references invalid resource attribute`
- **Cause:** IAM template references app stack resources
- **Fix:** Regenerate templates with updated config.yaml that excludes the offending role/policy

**Error:** `Unresolved resource dependencies [...] in the Resources block`
- **Cause:** IAM role references undefined resources (buckets, queues, other roles)
- **Fix:** Remove that role from `config.yaml` extraction list and regenerate

### Regeneration Required

Regenerate templates when:
- Source template (`stable.yaml`) is updated
- IAM extraction config needs changes
- Adding/removing IAM roles from split

## References

- IAM split script: `~/GitHub/scripts/iam-split/split_iam.py`
- Split configuration: `~/GitHub/scripts/iam-split/config.yaml`
- Usage documentation: `~/GitHub/scripts/iam-split/README.md`
- Source template: `test/fixtures/stable.yaml`
- Terraform config: `templates/external-iam.tf.j2`

## Architecture Decision Record

**Decision:** Minimal IAM extraction (2 roles + 3 policies)

**Context:** The monolithic CloudFormation template has deeply intertwined dependencies where IAM roles reference application resources created in the same stack.

**Consequences:**
- ✅ Achieves basic IAM/app separation for security boundaries
- ✅ IAM stack deploys independently and successfully
- ✅ Avoids circular dependency errors
- ⚠️ Most IAM resources remain in app stack
- ⚠️ Limited benefit for IAM-only updates

**Alternative Considered:** Extract all IAM resources
- **Rejected because:** Would require passing bucket ARNs as parameters to IAM stack, but buckets don't exist until app stack is deployed (chicken-and-egg problem)

**Future Improvement:** Refactor monolithic template to use wildcard permissions or parameter-based ARNs to enable more IAM extraction.

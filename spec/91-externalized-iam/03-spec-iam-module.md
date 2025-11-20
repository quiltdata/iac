# Specification: IAM Module

**Issue**: [#91 - externalized IAM](https://github.com/quiltdata/quilt-infrastructure/issues/91)

**Date**: 2025-11-20

**Branch**: 91-externalized-iam

**References**:

- [01-requirements.md](01-requirements.md)
- [02-analysis.md](02-analysis.md)

## Executive Summary

This specification defines the IAM module (`modules/iam/`) that will deploy and manage IAM resources separately from the application stack. The module provides an **optional** capability for enterprise customers with strict IAM governance requirements while maintaining full backward compatibility with the existing inline IAM pattern.

## Design Decisions

### Decision 1: Optional External IAM Pattern

**Decision**: External IAM is an **opt-in** feature, not a replacement

**Rationale**:

- Existing deployments use inline IAM and must continue to work
- Most customers don't require IAM separation
- Enterprise customers can opt in when needed
- No forced migration required

**Implications**:

- Module must be optional (conditionally created)
- Quilt module must support both patterns simultaneously
- Documentation must explain when to use each pattern

### Decision 2: Customer-Provided Split Templates

**Decision**: Customers provide pre-split IAM and application templates

**Rationale**:

- Split script already exists and works (`split_iam.py`)
- Terraform should not do YAML manipulation at deploy time
- Customers control exactly what IAM resources are externalized
- Clear separation of concerns

**Alternatives Rejected**:

- Terraform splits templates at runtime: Too complex, fragile
- Single template with conditions: Doesn't meet governance requirements

**Implications**:

- Module accepts IAM template file path as input
- Documentation provides split script usage examples
- Customers own the split process

### Decision 3: CloudFormation-Based IAM Stack

**Decision**: Deploy IAM resources via CloudFormation stack (not native Terraform IAM resources)

**Rationale**:

- Consistency with existing CloudFormation-based application stack
- Preserves all CloudFormation intrinsic functions and conditions
- Avoids HCL-to-YAML impedance mismatch
- Customers already understand CloudFormation syntax

**Alternatives Rejected**:

- Native Terraform `aws_iam_role` resources: Would require complete template rewrite
- Hybrid approach: Increases complexity unnecessarily

**Implications**:

- Module is a thin wrapper around `aws_cloudformation_stack`
- Template validation happens in CloudFormation
- Stack exports used for output propagation

### Decision 4: ARN-Only Outputs (No Role Name Outputs)

**Decision**: Module outputs only role/policy ARNs, not resource names

**Rationale**:

- Application stack requires ARNs for IAM properties (`Role: arn:aws:...`)
- ARNs are globally unique and unambiguous
- Names can be derived from ARNs if needed
- Simpler contract with fewer outputs

**Implications**:

- All 32 outputs are ARN strings
- Output naming: `{ResourceName}Arn` (e.g., `SearchHandlerRoleArn`)
- Validation uses ARN pattern matching

### Decision 5: Stack Naming Convention

**Decision**: IAM stack name is `{deployment_name}-iam` by default

**Rationale**:

- Consistent with existing naming patterns (VPC, RDS, ES use `var.name`)
- Explicit `-iam` suffix avoids collisions
- Predictable for automation and debugging
- Allows override if needed

**Implications**:

- Variable `var.name` used as base name
- CloudFormation export names: `{stack_name}-{ResourceName}Arn`
- Override via optional `var.iam_stack_name`

### Decision 6: No Circular Dependency Resolution

**Decision**: Module does not handle circular dependencies between IAM and application resources

**Rationale**:

- Customer responsibility to resolve via split script
- Common patterns: wildcards in policies, parameterized resources
- Too application-specific for generic module
- Existing split script already detects these issues

**Implications**:

- Module assumes clean IAM template with no app resource references
- Circular dependencies cause CloudFormation deployment failure
- Documentation explains resolution strategies

### Decision 7: Region-Specific Stacks (No Cross-Region Outputs)

**Decision**: Each region requires its own IAM stack deployment

**Rationale**:

- CloudFormation exports are region-scoped
- Cross-region export lookups not supported natively
- Multi-region deployments already deploy per-region infrastructure

**Implications**:

- IAM stack deployed in same region as application stack
- Multi-region = multiple IAM stacks
- Stack naming must be unique per region

## Module Interface

### Purpose

Deploy a CloudFormation stack containing IAM roles and policies that can be referenced by one or more application stacks.

### Module Location

```
modules/iam/
  ├── main.tf       # CloudFormation stack resource
  ├── variables.tf  # Input variables
  └── outputs.tf    # ARN outputs
```

### Input Variables

#### Required Variables

| Variable | Type | Description | Constraints |
|----------|------|-------------|-------------|
| `name` | `string` | Base name for the IAM stack | Used to generate stack name: `{name}-iam` |
| `template_url` | `string` | S3 URL of the IAM CloudFormation template | Must be valid S3 HTTPS URL |

#### Optional Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `iam_stack_name` | `string` | `null` | Override default stack name if provided |
| `parameters` | `map(string)` | `{}` | CloudFormation parameters to pass to IAM stack |
| `tags` | `map(string)` | `{}` | Tags to apply to the IAM stack |
| `capabilities` | `list(string)` | `["CAPABILITY_NAMED_IAM"]` | CloudFormation capabilities |

### Output Values

The module must output ARNs for all 32 IAM resources identified in the analysis:

#### IAM Role ARNs (24 outputs)

| Output Name | Description | Format |
|-------------|-------------|--------|
| `SearchHandlerRoleArn` | ARN of SearchHandlerRole | `arn:aws:iam::{account}:role/{name}` |
| `EsIngestRoleArn` | ARN of EsIngestRole | `arn:aws:iam::{account}:role/{name}` |
| `ManifestIndexerRoleArn` | ARN of ManifestIndexerRole | `arn:aws:iam::{account}:role/{name}` |
| `AccessCountsRoleArn` | ARN of AccessCountsRole | `arn:aws:iam::{account}:role/{name}` |
| `PkgEventsRoleArn` | ARN of PkgEventsRole | `arn:aws:iam::{account}:role/{name}` |
| `DuckDBSelectLambdaRoleArn` | ARN of DuckDBSelectLambdaRole | `arn:aws:iam::{account}:role/{name}` |
| `PkgPushRoleArn` | ARN of PkgPushRole | `arn:aws:iam::{account}:role/{name}` |
| `PackagerRoleArn` | ARN of PackagerRole | `arn:aws:iam::{account}:role/{name}` |
| `AmazonECSTaskExecutionRoleArn` | ARN of AmazonECSTaskExecutionRole | `arn:aws:iam::{account}:role/{name}` |
| `ManagedUserRoleArn` | ARN of ManagedUserRole | `arn:aws:iam::{account}:role/{name}` |
| `MigrationLambdaRoleArn` | ARN of MigrationLambdaRole | `arn:aws:iam::{account}:role/{name}` |
| `TrackingCronRoleArn` | ARN of TrackingCronRole | `arn:aws:iam::{account}:role/{name}` |
| `ApiRoleArn` | ARN of ApiRole | `arn:aws:iam::{account}:role/{name}` |
| `TimestampResourceHandlerRoleArn` | ARN of TimestampResourceHandlerRole | `arn:aws:iam::{account}:role/{name}` |
| `TabulatorRoleArn` | ARN of TabulatorRole | `arn:aws:iam::{account}:role/{name}` |
| `TabulatorOpenQueryRoleArn` | ARN of TabulatorOpenQueryRole | `arn:aws:iam::{account}:role/{name}` |
| `IcebergLambdaRoleArn` | ARN of IcebergLambdaRole | `arn:aws:iam::{account}:role/{name}` |
| `T4BucketReadRoleArn` | ARN of T4BucketReadRole | `arn:aws:iam::{account}:role/{name}` |
| `T4BucketWriteRoleArn` | ARN of T4BucketWriteRole | `arn:aws:iam::{account}:role/{name}` |
| `S3ProxyRoleArn` | ARN of S3ProxyRole | `arn:aws:iam::{account}:role/{name}` |
| `S3LambdaRoleArn` | ARN of S3LambdaRole | `arn:aws:iam::{account}:role/{name}` |
| `S3SNSToEventBridgeRoleArn` | ARN of S3SNSToEventBridgeRole | `arn:aws:iam::{account}:role/{name}` |
| `S3HashLambdaRoleArn` | ARN of S3HashLambdaRole | `arn:aws:iam::{account}:role/{name}` |
| `S3CopyLambdaRoleArn` | ARN of S3CopyLambdaRole | `arn:aws:iam::{account}:role/{name}` |

#### IAM Policy ARNs (8 outputs)

| Output Name | Description | Format |
|-------------|-------------|--------|
| `BucketReadPolicyArn` | ARN of BucketReadPolicy | `arn:aws:iam::{account}:policy/{name}` |
| `BucketWritePolicyArn` | ARN of BucketWritePolicy | `arn:aws:iam::{account}:policy/{name}` |
| `RegistryAssumeRolePolicyArn` | ARN of RegistryAssumeRolePolicy | `arn:aws:iam::{account}:policy/{name}` |
| `ManagedUserRoleBasePolicyArn` | ARN of ManagedUserRoleBasePolicy | `arn:aws:iam::{account}:policy/{name}` |
| `UserAthenaNonManagedRolePolicyArn` | ARN of UserAthenaNonManagedRolePolicy | `arn:aws:iam::{account}:policy/{name}` |
| `UserAthenaManagedRolePolicyArn` | ARN of UserAthenaManagedRolePolicy | `arn:aws:iam::{account}:policy/{name}` |
| `TabulatorOpenQueryPolicyArn` | ARN of TabulatorOpenQueryPolicy | `arn:aws:iam::{account}:policy/{name}` |
| `T4DefaultBucketReadPolicyArn` | ARN of T4DefaultBucketReadPolicy | `arn:aws:iam::{account}:policy/{name}` |

#### Stack Metadata Outputs

| Output Name | Type | Description |
|-------------|------|-------------|
| `stack_id` | `string` | CloudFormation stack ID |
| `stack_name` | `string` | CloudFormation stack name (for reference) |

## Behavior Specifications

### Stack Creation

**WHAT**: Module creates a CloudFormation stack from the provided IAM template

**Requirements**:

- Stack must be created in the same region as the caller
- Stack name must be unique within the region/account
- Stack must be tagged with provided tags
- Stack must use `CAPABILITY_NAMED_IAM` capability (default)

**Success Criteria**:

- CloudFormation stack reaches `CREATE_COMPLETE` state
- All IAM roles and policies are created
- Stack outputs contain all 32 ARNs

**Failure Modes**:

- Template URL inaccessible → Terraform fails with clear error
- Invalid IAM template syntax → CloudFormation validation error
- IAM resource naming conflicts → CloudFormation error
- Circular dependencies in template → CloudFormation error

### Stack Updates

**WHAT**: Module updates the IAM stack when template or parameters change

**Requirements**:

- Changes to `template_url` trigger stack update
- Changes to `parameters` trigger stack update
- Changes to `tags` trigger stack update
- Stack name changes cause replacement (destroy + recreate)

**Success Criteria**:

- Stack reaches `UPDATE_COMPLETE` state
- Outputs reflect updated resource ARNs
- No downtime if ARNs unchanged

**Failure Modes**:

- Update requires resource replacement → may cause app stack failures
- Update blocked by CloudFormation export constraints
- IAM policy changes rejected by AWS (size, syntax, permissions)

### Stack Deletion

**WHAT**: Module deletes the IAM stack when module instance is removed

**Requirements**:

- Stack deletion must be blocked if exports are imported by other stacks
- All IAM resources must be deleted with the stack
- Deletion must respect CloudFormation stack policies if set

**Success Criteria**:

- Stack deletion completes successfully
- All IAM resources removed from AWS
- No orphaned resources

**Failure Modes**:

- Exports still in use → CloudFormation blocks deletion
- IAM resources in use by running services → may cause application failures
- Stack deletion manually disabled → Terraform fails

### Output Propagation

**WHAT**: Module extracts ARNs from CloudFormation stack outputs and exposes as Terraform outputs

**Requirements**:

- Each CloudFormation output must map to a Terraform output
- Output names must match exactly (case-sensitive)
- Missing outputs in CloudFormation must cause Terraform error
- ARNs must be validated as proper AWS ARN format

**Success Criteria**:

- All 32 ARN outputs available to caller
- ARNs are valid AWS ARN strings
- Outputs update when stack updates

**Failure Modes**:

- CloudFormation template missing expected outputs → Terraform error
- Output naming mismatch → Terraform error
- Invalid ARN format in CloudFormation output → validation error

## IAM Template Requirements

The module expects the IAM CloudFormation template to conform to specific requirements:

### Required Template Structure

```yaml
Description: IAM roles and policies for Quilt application

Parameters:
  # Template may accept parameters for customization
  # Example: S3 bucket names, resource prefixes, etc.

Resources:
  # 24 IAM roles (as identified in analysis)
  SearchHandlerRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub '${AWS::StackName}-SearchHandlerRole'
      # ... role definition ...

  # 8 IAM managed policies
  BucketReadPolicy:
    Type: AWS::IAM::ManagedPolicy
    Properties:
      ManagedPolicyName: !Sub '${AWS::StackName}-BucketReadPolicy'
      # ... policy definition ...

Outputs:
  # Required: ARN outputs for all 32 resources
  SearchHandlerRoleArn:
    Description: ARN of SearchHandlerRole
    Value: !GetAtt SearchHandlerRole.Arn
    Export:
      Name: !Sub '${AWS::StackName}-SearchHandlerRoleArn'

  # ... 31 more outputs ...
```

### Template Constraints

**MUST**:

- Define all 24 IAM roles identified in analysis
- Define all 8 IAM managed policies identified in analysis
- Output ARN for every role and policy
- Use CloudFormation exports for all outputs
- Use `AWS::StackName` in export names to ensure uniqueness

**MUST NOT**:

- Reference application resources (SQS queues, S3 buckets, Lambda functions)
- Use `!GetAtt` to reference non-IAM resources
- Create resource-specific policies (bucket policies, queue policies)
- Depend on resources outside the IAM stack

**MAY**:

- Accept parameters for customization
- Use conditions for optional resources
- Use CloudFormation intrinsic functions within IAM definitions
- Define additional helper resources (e.g., custom CloudFormation resources)

## Validation Requirements

### Template URL Validation

**WHAT**: Validate that template URL is accessible and valid S3 HTTPS URL

**Validation Rules**:

- URL must start with `https://`
- URL must point to S3 bucket
- URL must be reachable (HTTP 200 response)
- File extension should be `.yaml` or `.yml` or `.json`

**Error Handling**:

- Invalid URL format → fail fast with clear error message
- Inaccessible URL → fail fast with clear error message
- Non-YAML/JSON content → CloudFormation will catch this

### Output Validation

**WHAT**: Validate that all expected outputs are present and have correct format

**Validation Rules**:

- All 32 outputs must be present in CloudFormation stack
- All outputs must match ARN pattern: `^arn:aws:iam::[0-9]{12}:(role|policy)/.*$`
- Output names must match exactly (case-sensitive)

**Error Handling**:

- Missing output → Terraform error with specific output name
- Invalid ARN format → Terraform validation error
- Unexpected output → warning (non-blocking)

## Non-Functional Requirements

### Performance

- Stack creation: Target < 5 minutes (CloudFormation dependent)
- Stack updates: Target < 3 minutes for non-disruptive changes
- Stack deletion: Target < 2 minutes if no export dependencies

### Reliability

- Module must handle transient CloudFormation API errors (retries)
- Module must detect stack drift (via Terraform state)
- Module must gracefully handle stack rollback scenarios

### Security

- Template URL must support private S3 buckets (via IAM permissions)
- Module must not log sensitive IAM policy contents
- Module must preserve CloudFormation stack policies

### Maintainability

- Module follows standard Terraform module structure
- Module uses consistent naming with other Quilt modules
- Module outputs are self-documenting with descriptions

## Integration Points

### With Quilt Module

**Interface**: Quilt module optionally calls IAM module and consumes outputs

**Contract**:

- IAM module provides 32 ARN outputs
- Quilt module passes these ARNs as parameters to application CloudFormation stack
- IAM stack must complete before application stack creation

**Dependencies**:

- IAM module has no dependency on Quilt module
- Quilt module depends on IAM module outputs (when used)

### With CloudFormation Templates

**Interface**: Module deploys customer-provided IAM template

**Contract**:

- Customer provides split IAM template (via split script)
- Template conforms to structure requirements above
- Template is stored in accessible S3 location

**Dependencies**:

- Module depends on template being pre-split by customer
- Module depends on S3 bucket accessibility

### With AWS IAM Service

**Interface**: CloudFormation creates IAM resources via AWS IAM API

**Contract**:

- Deployer has IAM permissions to create roles/policies
- IAM resources comply with AWS IAM limits
- Role/policy names are unique within account

**Dependencies**:

- AWS IAM service availability
- Sufficient IAM resource quotas
- Proper IAM permissions for deployer

## Success Criteria

### Functional Success

- ✅ Module creates CloudFormation IAM stack from template URL
- ✅ Module outputs all 32 IAM resource ARNs
- ✅ Module supports optional parameters and tags
- ✅ Module updates stack when inputs change
- ✅ Module deletes stack when removed
- ✅ Module validates outputs match expected format

### Integration Success

- ✅ Quilt module can consume IAM module outputs
- ✅ Application CloudFormation stack can reference IAM ARNs via parameters
- ✅ Split script output works as IAM template without modification

### Quality Success

- ✅ Module follows Quilt module conventions (naming, structure)
- ✅ Module has clear variable descriptions and validation
- ✅ Module has comprehensive output descriptions
- ✅ Module handles errors gracefully with clear messages

### Documentation Success

- ✅ Module variables documented with examples
- ✅ Module outputs documented with usage examples
- ✅ Module README explains when to use external IAM
- ✅ Examples show integration with Quilt module

## Out of Scope

This module explicitly **does not**:

- ❌ Split CloudFormation templates (customer responsibility)
- ❌ Resolve circular dependencies (customer responsibility)
- ❌ Validate IAM policy correctness (AWS responsibility)
- ❌ Manage IAM users or groups (only roles and policies)
- ❌ Create resource-specific policies (bucket policies, etc.)
- ❌ Handle cross-account IAM delegation
- ❌ Support cross-region IAM export lookups
- ❌ Migrate existing inline IAM to external IAM
- ❌ Provide pre-built IAM templates (customer provides)

## Open Questions

None. All design decisions have been made.

## References

- Analysis document: [02-analysis.md](02-analysis.md)
- Requirements document: [01-requirements.md](01-requirements.md)
- IAM split script: `/Users/ernest/GitHub/scripts/iam-split/split_iam.py`
- CloudFormation IAM resource docs: <https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/AWS_IAM.html>

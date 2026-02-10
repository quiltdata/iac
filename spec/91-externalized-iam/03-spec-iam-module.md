# Specification: IAM Module

**Issue**: [#91 - externalized IAM](https://github.com/quiltdata/quilt-infrastructure/issues/91)

**Date**: 2025-11-20

**Branch**: 91-externalized-iam

**References**:

- [01-requirements.md](01-requirements.md)
- [02-analysis.md](02-analysis.md)
- [config.yaml](config.yaml) - **Source of truth for IAM resources**

## Executive Summary

This specification defines the IAM module (`modules/iam/`) that deploys Quilt-provided IAM CloudFormation templates separately from the application stack. The module is designed to work with **Quilt's official split templates** and provides an **optional** capability for enterprise customers with strict IAM governance requirements while maintaining full backward compatibility.

## Design Decisions

### Decision 1: Quilt-Controlled Templates

**Decision**: Templates are owned, generated, and distributed by Quilt

**Rationale**:
- Quilt maintains the IAM resource definitions
- Quilt controls which resources are externalized (via config.yaml)
- Customers receive templates as part of Quilt release
- Ensures consistency and supportability

**Implications**:
- Module is designed for Quilt's template structure
- config.yaml defines expected outputs
- Module version must match template version
- Breaking template changes = breaking module changes

### Decision 2: Config-Driven Output Expectations

**Decision**: Module expects outputs defined in config.yaml, not hardcoded list

**Rationale**:
- config.yaml is single source of truth
- IAM resources may change over Quilt versions
- Module validates against config, not arbitrary list
- Enables evolution without module rewrite

**Implications**:
- config.yaml checked into spec directory
- Module references config for validation
- Documentation generated from config
- Version compatibility enforced

### Decision 3: Optional External IAM Pattern

**Decision**: External IAM is **opt-in** feature, not a replacement

**Rationale**:
- Existing deployments use inline IAM and must continue to work
- Most customers don't require IAM separation
- Enterprise customers can opt in when needed
- No forced migration required

**Implications**:
- Module must be optional (conditionally created)
- Quilt module must support both patterns simultaneously
- Documentation must explain when to use each pattern

### Decision 4: CloudFormation-Based IAM Stack

**Decision**: Deploy IAM resources via CloudFormation stack (not native Terraform IAM resources)

**Rationale**:
- Consistency with existing CloudFormation-based application stack
- Preserves all CloudFormation intrinsic functions and conditions
- Quilt already maintains CloudFormation templates
- Customers already understand CloudFormation

**Alternatives Rejected**:
- Native Terraform `aws_iam_role` resources: Would require complete template rewrite
- Hybrid approach: Increases complexity unnecessarily

**Implications**:
- Module is a thin wrapper around `aws_cloudformation_stack`
- Template validation happens in CloudFormation
- Stack exports used for output propagation

### Decision 5: ARN-Only Outputs (No Role Name Outputs)

**Decision**: Module outputs only role/policy ARNs, not resource names

**Rationale**:
- Application stack requires ARNs for IAM properties (`Role: arn:aws:...`)
- ARNs are globally unique and unambiguous
- Names can be derived from ARNs if needed
- Simpler contract with fewer outputs

**Implications**:
- All outputs are ARN strings
- Output naming: `{ResourceName}Arn` (e.g., `SearchHandlerRoleArn`)
- Validation uses ARN pattern matching

### Decision 6: Stack Naming Convention

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

Deploy a CloudFormation stack containing IAM roles and policies (as defined in Quilt's config.yaml) that can be referenced by the application stack.

### Module Location

```
modules/iam/
  ├── main.tf       # CloudFormation stack resource
  ├── variables.tf  # Input variables
  └── outputs.tf    # ARN outputs (derived from config.yaml)
```

### Input Variables

#### Required Variables

| Variable | Type | Description | Constraints |
|----------|------|-------------|-------------|
| `name` | `string` | Base name for the IAM stack | Used to generate stack name: `{name}-iam` |
| `template_url` | `string` | S3 URL of Quilt's IAM CloudFormation template | Must be valid S3 HTTPS URL |

#### Optional Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `iam_stack_name` | `string` | `null` | Override default stack name if provided |
| `parameters` | `map(string)` | `{}` | CloudFormation parameters to pass to IAM stack |
| `tags` | `map(string)` | `{}` | Tags to apply to the IAM stack |
| `capabilities` | `list(string)` | `["CAPABILITY_NAMED_IAM"]` | CloudFormation capabilities |

### Output Values

The module outputs ARNs for all IAM resources defined in [config.yaml](config.yaml):

#### IAM Role ARNs (24 outputs per config.yaml)

Roles extracted from config.yaml (`extraction.roles`):

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

#### IAM Policy ARNs (8 outputs per config.yaml)

Policies extracted from config.yaml (`extraction.policies`):

- `BucketReadPolicyArn`
- `BucketWritePolicyArn`
- `RegistryAssumeRolePolicyArn`
- `ManagedUserRoleBasePolicyArn`
- `UserAthenaNonManagedRolePolicyArn`
- `UserAthenaManagedRolePolicyArn`
- `TabulatorOpenQueryPolicyArn`
- `T4DefaultBucketReadPolicyArn`

#### Stack Metadata Outputs

| Output Name | Type | Description |
|-------------|------|-------------|
| `stack_id` | `string` | CloudFormation stack ID |
| `stack_name` | `string` | CloudFormation stack name (for reference) |

**Total Outputs**: 34 (24 roles + 8 policies + 2 metadata)

## Behavior Specifications

### Stack Creation

**WHAT**: Module creates a CloudFormation stack from Quilt's IAM template

**Requirements**:
- Stack must be created in the same region as the caller
- Stack name must be unique within the region/account
- Stack must be tagged with provided tags
- Stack must use `CAPABILITY_NAMED_IAM` capability (default)

**Success Criteria**:
- CloudFormation stack reaches `CREATE_COMPLETE` state
- All IAM roles and policies (per config.yaml) are created
- Stack outputs contain all expected ARNs

**Failure Modes**:
- Template URL inaccessible → Terraform fails with clear error
- Invalid IAM template syntax → CloudFormation validation error
- IAM resource naming conflicts → CloudFormation error
- Circular dependencies in template → CloudFormation error (should not happen with Quilt templates)

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
- Output names must match config.yaml expectations exactly (case-sensitive)
- Missing outputs in CloudFormation must cause Terraform error
- ARNs must be validated as proper AWS ARN format

**Success Criteria**:
- All expected ARN outputs (per config.yaml) available to caller
- ARNs are valid AWS ARN strings
- Outputs update when stack updates

**Failure Modes**:
- CloudFormation template missing expected outputs → Terraform error
- Output naming mismatch → Terraform error
- Invalid ARN format in CloudFormation output → validation error

## IAM Template Requirements

The module expects Quilt's IAM CloudFormation template to conform to the structure produced by the split script:

### Required Template Structure

```yaml
Description: Quilt IAM roles and policies (externalized)

Parameters:
  # Optional parameters for customization

Resources:
  # 24 IAM roles (as defined in config.yaml)
  SearchHandlerRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub '${AWS::StackName}-SearchHandlerRole'
      # ... role definition ...

  # 8 IAM managed policies (as defined in config.yaml)
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
- Define all IAM roles listed in config.yaml (`extraction.roles`)
- Define all IAM managed policies listed in config.yaml (`extraction.policies`)
- Output ARN for every role and policy
- Use CloudFormation exports for all outputs
- Use `AWS::StackName` in export names to ensure uniqueness

**MUST NOT**:
- Reference application resources (SQS queues, S3 buckets, Lambda functions)
- Use `!GetAtt` to reference non-IAM resources
- Create resource-specific policies (listed in config.yaml `extraction.exclude_policies`)
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

**WHAT**: Validate that all expected outputs (per config.yaml) are present and have correct format

**Validation Rules**:
- All outputs defined in config.yaml must be present in CloudFormation stack
- Role outputs must match ARN pattern from config.yaml: `^arn:aws:iam::[0-9]{12}:role\/[a-zA-Z0-9+=,.@_\-\/]+$`
- Policy outputs must match ARN pattern from config.yaml: `^arn:aws:iam::[0-9]{12}:policy\/[a-zA-Z0-9+=,.@_\-\/]+$`
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
- Module documentation references config.yaml

## Integration Points

### With Quilt Module

**Interface**: Quilt module optionally calls IAM module and consumes outputs

**Contract**:
- IAM module provides ARN outputs for all resources in config.yaml
- Quilt module passes these ARNs as parameters to application CloudFormation stack
- IAM stack must complete before application stack creation

**Dependencies**:
- IAM module has no dependency on Quilt module
- Quilt module depends on IAM module outputs (when used)

### With Quilt's CloudFormation Templates

**Interface**: Module deploys Quilt-provided IAM template

**Contract**:
- Quilt provides split IAM template (generated via split script)
- Template conforms to structure requirements above
- Template is distributed with Quilt releases
- Customer uploads template to their S3 bucket

**Dependencies**:
- Module depends on template being generated by Quilt
- Module version must match template version
- Template must conform to config.yaml

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

## Version Compatibility

**CRITICAL**: Module version must match Quilt template version

**Compatibility Matrix**:
- Module v1.x.x → Quilt templates v1.x.x (config.yaml with 24 roles, 8 policies)
- Future versions may add/remove IAM resources → config.yaml updated → module updated

**Breaking Changes**:
- Adding IAM resources to config.yaml → minor version bump
- Removing IAM resources from config.yaml → major version bump
- Renaming IAM resources in config.yaml → major version bump

**Release Process**:
1. Quilt updates config.yaml
2. Quilt runs split script to generate new templates
3. Quilt updates module outputs.tf to match config.yaml
4. Quilt tests module with new templates
5. Quilt releases module + templates together

## Success Criteria

### Functional Success

- ✅ Module creates CloudFormation IAM stack from Quilt's template URL
- ✅ Module outputs all IAM resource ARNs defined in config.yaml
- ✅ Module supports optional parameters and tags
- ✅ Module updates stack when inputs change
- ✅ Module deletes stack when removed
- ✅ Module validates outputs match config.yaml expectations

### Integration Success

- ✅ Quilt module can consume IAM module outputs
- ✅ Application CloudFormation stack can reference IAM ARNs via parameters
- ✅ Quilt's split script output works as IAM template without modification

### Quality Success

- ✅ Module follows Quilt module conventions (naming, structure)
- ✅ Module has clear variable descriptions and validation
- ✅ Module has comprehensive output descriptions
- ✅ Module handles errors gracefully with clear messages
- ✅ Module documentation references config.yaml as source of truth

### Documentation Success

- ✅ Module variables documented with examples
- ✅ Module outputs documented with usage examples
- ✅ Module README explains when to use external IAM
- ✅ Examples show integration with Quilt module
- ✅ Version compatibility clearly documented

## Out of Scope

This module explicitly **does not**:

- ❌ Split CloudFormation templates (Quilt's build process responsibility)
- ❌ Generate config.yaml (Quilt maintains this)
- ❌ Validate IAM policy correctness (AWS responsibility)
- ❌ Manage IAM users or groups (only roles and policies)
- ❌ Create resource-specific policies (bucket policies, etc.)
- ❌ Handle cross-account IAM delegation
- ❌ Support cross-region IAM export lookups
- ❌ Migrate existing inline IAM to external IAM
- ❌ Provide customizable IAM templates (Quilt provides official templates)

## Open Questions

None. All design decisions have been made.

## References

- Analysis document: [02-analysis.md](02-analysis.md)
- Requirements document: [01-requirements.md](01-requirements.md)
- IAM resource configuration: [config.yaml](config.yaml) - **Source of truth**
- IAM split script: `/Users/ernest/GitHub/scripts/iam-split/split_iam.py`
- CloudFormation IAM resource docs: <https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/AWS_IAM.html>

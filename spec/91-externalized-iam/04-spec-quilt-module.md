# Specification: Quilt Module Modifications

**Issue**: [#91 - externalized IAM](https://github.com/quiltdata/quilt-infrastructure/issues/91)

**Date**: 2025-11-20

**Branch**: 91-externalized-iam

**References**:

- [01-requirements.md](01-requirements.md)
- [02-analysis.md](02-analysis.md)
- [03-spec-iam-module.md](03-spec-iam-module.md)

## Executive Summary

This specification defines modifications to the existing Quilt module (`modules/quilt/`) to support **optional** external IAM resources. The module must support two deployment patterns simultaneously: the existing inline IAM pattern (default) and the new external IAM pattern (opt-in), ensuring full backward compatibility.

## Design Decisions

### Decision 1: Conditional IAM Module Usage

**Decision**: Use `count` meta-argument to conditionally instantiate IAM module

**Rationale**:

- Terraform standard pattern for optional resources
- Clear boolean logic: "if IAM template URL provided, use external IAM"
- No ambiguity about which pattern is active
- Modules not created = zero cost/complexity when not used

**Implementation Indicator**:

```hcl
module "iam" {
  count = var.iam_template_url != null ? 1 : 0
  # ...
}
```

**Alternatives Rejected**:

- Separate module variants (quilt-with-iam, quilt-without-iam): Maintenance burden
- Feature flags: Less idiomatic than count-based conditionals

**Implications**:

- Variable `var.iam_template_url` is the activation trigger
- When `null` (default): inline IAM pattern (backward compatible)
- When set: external IAM pattern with module instantiation

### Decision 2: Parameter Merge Strategy

**Decision**: Merge IAM parameters conditionally into CloudFormation parameters

**Rationale**:

- Existing parameter merge pattern already works well
- IAM parameters are just another set of auto-generated parameters
- Conditional merge ensures parameters only passed when external IAM used
- No impact on inline IAM deployments

**Implementation Indicator**:

```hcl
parameters = merge(
  var.parameters,              # User overrides (first priority)
  local.iam_parameters,        # IAM ARNs (if external IAM)
  {                           # Infrastructure outputs
    VPC = module.vpc.vpc_id,
    DBUrl = local.db_url,
    # ... existing parameters
  }
)
```

**Implications**:

- `local.iam_parameters` is empty map when inline IAM used
- `local.iam_parameters` contains 32 ARN mappings when external IAM used
- User can override IAM parameters via `var.parameters` if needed

### Decision 3: IAM Stack Output Lookup Pattern

**Decision**: Use `aws_cloudformation_stack` data source to query IAM stack outputs

**Rationale**:

- Native Terraform pattern for CloudFormation integration
- Reads outputs directly from CloudFormation API
- Creates implicit dependency (IAM stack must exist before query)
- No custom scripting or external tools required

**Implementation Indicator**:

```hcl
data "aws_cloudformation_stack" "iam" {
  count = var.iam_template_url != null ? 1 : 0
  name  = var.iam_stack_name != null ? var.iam_stack_name : "${var.name}-iam"
}
```

**Alternatives Rejected**:

- Direct module outputs: Would tightly couple modules
- SSM Parameter Store: Extra infrastructure, eventual consistency issues
- S3-based state sharing: Complex, not real-time

**Implications**:

- Data source only created when external IAM pattern active
- Query happens during Terraform plan phase
- Failure to find stack causes immediate Terraform error

### Decision 4: Template Storage Consistency

**Decision**: External IAM template uses same S3 bucket pattern as application template

**Rationale**:

- Consistency with existing `aws_s3_object` resource for app template
- Same access controls and lifecycle management
- Same template URL generation pattern
- Customers already understand this pattern

**Implementation Indicator**:

- Existing: `s3://quilt-templates-{name}/quilt.yaml`
- External IAM: `s3://quilt-templates-{name}/quilt-iam.yaml`

**Implications**:

- Two S3 objects in same bucket per deployment
- Separate upload workflows for IAM and app templates
- IAM template must be uploaded before module instantiation

### Decision 5: No Template Splitting in Module

**Decision**: Module does not split templates; customers provide pre-split templates

**Rationale**:

- Splitting is customer workflow concern, not infrastructure concern
- Split script already exists and works
- Module should be declarative, not imperative
- Avoids complex YAML manipulation in Terraform

**Alternatives Rejected**:

- Terraform `external` data source calling split script: Too implicit, hard to debug
- Terraform template splitting logic: Not Terraform's strength
- Automatic detection and splitting: Too magical, unpredictable

**Implications**:

- Customer must run split script before deployment
- Module assumes templates are already split
- Documentation must explain split workflow clearly

### Decision 6: Backward Compatibility Guarantee

**Decision**: Default behavior is unchanged; new variables default to `null`

**Rationale**:

- Existing deployments must continue working without modification
- No forced upgrades or migrations
- New functionality is additive, not replacement
- Follows Terraform best practices for module evolution

**Implementation Indicator**:

```hcl
variable "iam_template_url" {
  type    = string
  default = null  # null = inline IAM (existing behavior)
}
```

**Implications**:

- Zero changes required for existing users
- New users explicitly opt into external IAM
- Documentation must explain both patterns

### Decision 7: Single Stack Name Variable

**Decision**: Provide one variable for IAM stack name with smart default

**Rationale**:

- Most users will want default naming (`{name}-iam`)
- Advanced users can override if needed (multi-region, etc.)
- Reduces variable proliferation
- Consistent with other module patterns

**Alternatives Rejected**:

- Separate prefix/suffix variables: Over-engineered
- Auto-generated unique names: Not predictable, hard to reference

**Implications**:

- Variable `var.iam_stack_name` is optional
- Default: `${var.name}-iam`
- Override for advanced scenarios only

## Module Interface Changes

### New Input Variables

| Variable | Type | Default | Required | Description |
|----------|------|---------|----------|-------------|
| `iam_template_url` | `string` | `null` | No | S3 HTTPS URL of IAM CloudFormation template. If null, use inline IAM pattern. |
| `iam_stack_name` | `string` | `null` | No | Override IAM stack name. Default: `{name}-iam` |
| `iam_parameters` | `map(string)` | `{}` | No | CloudFormation parameters to pass to IAM stack |
| `iam_tags` | `map(string)` | `{}` | No | Additional tags for IAM stack (merged with global tags) |

### Existing Variables (Unchanged)

All existing variables remain unchanged:

- `name` - Deployment name
- `parameters` - CloudFormation parameters for application stack
- `template_url` - Application template URL (currently derived from uploaded S3 object)
- `tags` - Tags for all resources
- All infrastructure variables (VPC, DB, ElasticSearch, etc.)

### New Outputs (Conditional)

These outputs are only populated when external IAM pattern is used:

| Output | Type | Description |
|--------|------|-------------|
| `iam_stack_id` | `string` | CloudFormation IAM stack ID (null if inline IAM) |
| `iam_stack_name` | `string` | CloudFormation IAM stack name (null if inline IAM) |
| `iam_role_arns` | `map(string)` | Map of role names to ARNs (empty if inline IAM) |
| `iam_policy_arns` | `map(string)` | Map of policy names to ARNs (empty if inline IAM) |

### Existing Outputs (Unchanged)

All existing outputs remain unchanged:

- `stack_id` - Application CloudFormation stack ID
- `vpc_id`, `db_endpoint`, `search_endpoint`, etc.

## Behavior Specifications

### Pattern Selection Logic

**WHAT**: Module determines which IAM pattern to use based on `var.iam_template_url`

**Logic**:

```
IF var.iam_template_url == null THEN
  Use inline IAM pattern (existing behavior)
  - Deploy application CloudFormation stack with inline IAM resources
  - No IAM module instantiation
  - No IAM parameters passed to application stack
ELSE
  Use external IAM pattern (new behavior)
  - Instantiate IAM module with count = 1
  - Deploy IAM CloudFormation stack first
  - Query IAM stack outputs
  - Pass IAM ARNs as parameters to application stack
  - Deploy application CloudFormation stack with parameterized IAM
END IF
```

**Success Criteria**:

- Pattern selection happens automatically based on variable
- No ambiguity about which pattern is active
- Terraform plan shows which resources will be created

**Failure Modes**:

- `var.iam_template_url` set but IAM stack doesn't exist → Terraform error
- IAM template URL inaccessible → IAM module fails
- Application template expects inline IAM but external IAM used → CloudFormation error

### IAM Module Instantiation

**WHAT**: Conditionally create IAM module when external IAM pattern is active

**Requirements**:

- IAM module created only when `var.iam_template_url != null`
- IAM module receives template URL, parameters, tags, and name
- IAM module completes before application stack creation
- IAM module outputs are available for parameter passing

**Success Criteria**:

- IAM module instantiated when external IAM pattern active
- IAM module not instantiated when inline IAM pattern active
- Terraform plan clearly shows IAM module resources (or lack thereof)

**Failure Modes**:

- IAM module fails to create stack → Terraform apply fails
- IAM module takes too long → Terraform timeout
- IAM module missing required outputs → data source query fails

### IAM Stack Output Query

**WHAT**: Query CloudFormation API for IAM stack outputs and map to parameter structure

**Requirements**:

- Data source queries IAM stack by name (default or override)
- Query happens during Terraform plan phase
- All 32 outputs must be present in IAM stack
- Outputs are validated as proper ARN format

**Success Criteria**:

- All 32 ARNs retrieved from IAM stack outputs
- ARNs mapped to correct parameter names for application stack
- Data source refresh detects IAM stack changes

**Failure Modes**:

- IAM stack not found → Terraform error with helpful message
- IAM stack missing outputs → Terraform error listing missing outputs
- IAM stack in failed state → Terraform error with stack status

### Parameter Transformation

**WHAT**: Transform IAM module outputs into CloudFormation parameter format

**Transformation Rules**:

| IAM Module Output | CloudFormation Parameter Name |
|-------------------|------------------------------|
| `SearchHandlerRoleArn` | `SearchHandlerRole` |
| `EsIngestRoleArn` | `EsIngestRole` |
| `BucketReadPolicyArn` | `BucketReadPolicy` |
| ... (30 more) | ... |

**Pattern**: Remove `Arn` suffix from output name → parameter name

**Requirements**:

- All 32 IAM outputs transformed to parameters
- Parameter names match exactly what application template expects
- Transformation happens in local value for clarity

**Success Criteria**:

- Application stack receives all required IAM parameters
- Parameter names match application template parameter definitions
- No manual mapping required by user

**Failure Modes**:

- Output name mismatch → parameter name mismatch → CloudFormation error
- Missing transformation → missing parameter → CloudFormation validation error

### Application Stack Deployment

**WHAT**: Deploy application CloudFormation stack with IAM parameters (when external IAM used)

**Requirements**:

- Stack deployed after IAM stack completes (implicit dependency)
- Stack receives 32 IAM parameters (when external IAM used)
- Stack receives 0 IAM parameters (when inline IAM used)
- Stack still receives all existing infrastructure parameters

**Success Criteria**:

- Application stack creates successfully
- Lambda functions, ECS tasks, etc. reference external IAM roles correctly
- No downtime during deployment

**Failure Modes**:

- IAM ARNs don't match application template parameters → CloudFormation validation error
- IAM roles don't have required permissions → runtime errors in application
- IAM stack deleted before application stack → dangling references

### Stack Updates and Dependencies

**WHAT**: Handle updates to IAM stack and propagate to application stack

**Scenarios**:

1. **IAM stack update (no ARN changes)**:
   - IAM stack updates in-place
   - Application stack unchanged
   - No downtime

2. **IAM stack update (ARN changes)**:
   - IAM stack updates, ARNs change
   - Application stack parameters change
   - Application stack updates to reference new ARNs
   - Possible brief service disruption

3. **Switch from inline to external IAM**:
   - NOT SUPPORTED - requires template change
   - Customer must migrate manually

4. **Switch from external to inline IAM**:
   - NOT SUPPORTED - requires template change
   - Customer must migrate manually

**Requirements**:

- Terraform dependency graph ensures correct update order
- IAM stack updates complete before application stack updates
- Parameter changes trigger application stack updates

**Success Criteria**:

- Updates apply in correct order automatically
- Terraform plan shows cascading changes
- State remains consistent after updates

**Failure Modes**:

- IAM stack update fails → application stack not updated (good)
- Application stack update fails → may reference old IAM ARNs
- Concurrent updates cause conflicts

## Integration Points

### With IAM Module

**Interface**: Quilt module instantiates IAM module and consumes outputs

**Contract**:

- Quilt module passes: `name`, `template_url`, `parameters`, `tags`
- IAM module provides: 32 ARN outputs + stack metadata
- IAM module completes before application stack creation

**Dependencies**:

- Quilt → IAM (when external IAM pattern active)
- Implicit Terraform dependency via data source

### With CloudFormation Application Template

**Interface**: Quilt module passes IAM parameters to application template

**Contract**:

- Application template defines 32 IAM parameters (when split)
- Application template uses inline IAM resources (when not split)
- Quilt module detects which pattern via `var.iam_template_url`

**Dependencies**:

- Application template must match IAM pattern selected
- Template split must be done by customer before deployment

### With S3 Template Storage

**Interface**: Quilt module uploads templates to S3 bucket

**Current State**: Module already uploads application template
**New Requirement**: Customer must upload IAM template separately

**Contract**:

- Bucket naming: `quilt-templates-{name}`
- Application template: `quilt.yaml` or `quilt-app.yaml`
- IAM template: `quilt-iam.yaml`
- Both templates in same bucket

**Dependencies**:

- IAM template must be uploaded before Terraform apply
- Bucket must exist and be accessible
- Template URLs must be valid S3 HTTPS URLs

### With Existing Infrastructure Modules

**Interface**: VPC, DB, ElasticSearch modules unchanged

**Contract**:

- No changes to existing module integration
- Parameter passing pattern remains the same
- IAM parameters added to existing parameter merge

**Dependencies**:

- No new dependencies on infrastructure modules
- Infrastructure modules unaware of IAM pattern

## Validation Requirements

### Variable Validation

**WHAT**: Validate input variables before module execution

**Validation Rules**:

1. **IAM Template URL**:
   - If provided, must be valid S3 HTTPS URL
   - Pattern: `^https://[a-z0-9-]+\\.s3\\..*\\.amazonaws\\.com/.*\\.(yaml|yml|json)$`

2. **IAM Stack Name**:
   - If provided, must be valid CloudFormation stack name
   - Pattern: `^[a-zA-Z][a-zA-Z0-9-]*$`
   - Max length: 128 characters

3. **IAM Parameters**:
   - Must be map of strings
   - Keys must be valid CloudFormation parameter names

**Error Handling**:

- Invalid URL → Terraform validation error before apply
- Invalid stack name → Terraform validation error before apply
- Invalid parameters → CloudFormation will validate

### Pattern Consistency Validation

**WHAT**: Ensure IAM pattern and template match

**Challenge**: Terraform cannot inspect CloudFormation template contents

**Approach**: Detect mismatch at CloudFormation deployment time

**Mismatch Scenarios**:

1. **External IAM pattern + Inline IAM template**:
   - IAM parameters passed to application stack
   - Template doesn't expect these parameters
   - CloudFormation validation error: "Unexpected parameter: SearchHandlerRole"

2. **Inline IAM pattern + Split IAM template**:
   - No IAM parameters passed to application stack
   - Template expects IAM parameters
   - CloudFormation validation error: "Required parameter missing: SearchHandlerRole"

**Error Handling**:

- CloudFormation catches these errors during validation
- Terraform reports CloudFormation error to user
- User must fix template or change pattern

**Decision**: This is acceptable - CloudFormation is the source of truth for template requirements

### Output Availability Validation

**WHAT**: Ensure all expected outputs are present in IAM stack

**Validation Rules**:

- All 32 outputs must be present when querying IAM stack
- Output values must match ARN pattern
- Output names must match expected names exactly

**Error Handling**:

- Missing output → Terraform error listing missing output names
- Invalid ARN format → Terraform validation error
- Unexpected outputs → warning only (non-blocking)

## Non-Functional Requirements

### Backward Compatibility

**Requirement**: Existing deployments continue working without changes

**Verification**:

- Existing Terraform configurations apply without modification
- No new required variables
- Default behavior matches existing behavior
- No breaking changes to outputs

**Success Criteria**:

- Zero customer impact for users not adopting external IAM
- Upgrade to new module version requires no code changes

### Performance

**Requirement**: External IAM pattern should not significantly increase deployment time

**Targets**:

- IAM stack creation: < 5 minutes
- Output query: < 30 seconds
- Total overhead: < 10% of total deployment time

**Success Criteria**:

- Deployment time comparable to inline IAM pattern
- Terraform plan performance not degraded

### Usability

**Requirement**: Clear error messages and intuitive behavior

**Requirements**:

- Variable descriptions explain when to use external IAM
- Terraform plan clearly shows which pattern is active
- Error messages include remediation guidance
- Documentation provides migration examples

**Success Criteria**:

- Users can determine which pattern they're using from Terraform plan
- Errors clearly indicate whether issue is in IAM stack or app stack
- Documentation answers common questions

### Reliability

**Requirement**: Consistent behavior across multiple deployments and updates

**Requirements**:

- Pattern selection logic is deterministic
- State consistency maintained across updates
- Failure in one stack doesn't corrupt other stack's state
- Rollback scenarios handled gracefully

**Success Criteria**:

- No state corruption scenarios
- Failed deployments can be retried safely
- Partial deployments are detectable and recoverable

## Success Criteria

### Functional Success

- ✅ Module supports both inline and external IAM patterns
- ✅ Pattern selection based on `var.iam_template_url` value
- ✅ IAM module instantiated conditionally
- ✅ IAM stack outputs queried and transformed to parameters
- ✅ Application stack receives correct parameters for pattern used
- ✅ Backward compatibility maintained (existing deployments work)

### Integration Success

- ✅ IAM module integration works correctly
- ✅ CloudFormation parameter passing works for external IAM
- ✅ Terraform dependency graph ensures correct ordering
- ✅ Split templates from split script work without modification

### Quality Success

- ✅ Variable validation prevents common errors
- ✅ Error messages are clear and actionable
- ✅ Terraform plan output clearly shows pattern and resources
- ✅ Code follows existing module conventions

### Documentation Success

- ✅ Variable documentation explains both patterns
- ✅ Examples show both inline and external IAM deployments
- ✅ Migration guide explains how to adopt external IAM
- ✅ Troubleshooting guide covers common error scenarios

## Out of Scope

This specification explicitly **does not**:

- ❌ Automatic template splitting (customer responsibility)
- ❌ Template validation before deployment (CloudFormation responsibility)
- ❌ Migration tools for existing deployments
- ❌ Automated pattern detection from template contents
- ❌ Support for switching patterns post-deployment
- ❌ Cross-region IAM stack references
- ❌ Multi-account IAM delegation patterns
- ❌ IAM policy correctness validation
- ❌ Rollback logic beyond Terraform/CloudFormation defaults

## Migration Guidance (Informational)

While migration tools are out of scope, this section clarifies the expected customer workflow:

### New Deployments (External IAM)

1. Customer obtains CloudFormation templates (app + IAM)
2. Customer runs split script if templates not pre-split
3. Customer uploads IAM template to S3
4. Customer uploads app template to S3
5. Customer sets `var.iam_template_url` in Terraform
6. Customer runs `terraform apply`

### Existing Deployments (Remain Inline IAM)

1. Customer updates Terraform to new module version
2. No configuration changes required
3. Customer runs `terraform apply` (no-op or minimal changes)
4. Deployment continues using inline IAM pattern

### Existing Deployments (Migrate to External IAM)

**WARNING**: Migration is disruptive and requires careful planning

**Steps** (high-level, customer responsibility):

1. Customer runs split script on existing template
2. Customer reviews split templates for correctness
3. Customer plans migration window (downtime expected)
4. Customer deploys IAM stack separately
5. Customer updates application template to reference external IAM
6. Customer updates Terraform configuration with `var.iam_template_url`
7. Customer applies changes (may require stack replacement)

**Recommendation**: Only migrate if IAM governance requirements mandate it

## Open Questions

None. All design decisions have been made.

## References

- Analysis document: [02-analysis.md](02-analysis.md)
- Requirements document: [01-requirements.md](01-requirements.md)
- IAM module specification: [03-spec-iam-module.md](03-spec-iam-module.md)
- Existing Quilt module: [/modules/quilt/main.tf](../../modules/quilt/main.tf)
- CloudFormation stack resource docs: <https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack>
- CloudFormation stack data source docs: <https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/cloudformation_stack>

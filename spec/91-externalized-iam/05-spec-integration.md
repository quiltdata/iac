# Specification: End-to-End Integration and Workflows

**Issue**: [#91 - externalized IAM](https://github.com/quiltdata/quilt-infrastructure/issues/91)

**Date**: 2025-11-20

**Branch**: 91-externalized-iam

**References**:

- [01-requirements.md](01-requirements.md)
- [02-analysis.md](02-analysis.md)
- [03-spec-iam-module.md](03-spec-iam-module.md)
- [04-spec-quilt-module.md](04-spec-quilt-module.md)

## Executive Summary

This specification defines the end-to-end integration between the IAM module, Quilt module, CloudFormation templates, and customer workflows. It establishes the complete picture of how all components work together to deliver the externalized IAM capability.

## System Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Customer Workflow                        │
│                                                                   │
│  1. Split Template     2. Upload Templates    3. Run Terraform   │
│     (split_iam.py) ──────▶ (S3 Bucket) ─────────▶ (terraform)   │
└─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Terraform Quilt Module                        │
│                    (modules/quilt/main.tf)                       │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ IF var.iam_template_url != null THEN                     │   │
│  │                                                           │   │
│  │   ┌──────────────────────────────────────────────┐      │   │
│  │   │ module "iam" (modules/iam/)                  │      │   │
│  │   │   - Deploy IAM CloudFormation Stack          │      │   │
│  │   │   - Output 32 IAM ARNs                       │      │   │
│  │   └──────────────────────────────────────────────┘      │   │
│  │              │                                            │   │
│  │              ▼                                            │   │
│  │   ┌──────────────────────────────────────────────┐      │   │
│  │   │ data "aws_cloudformation_stack" "iam"        │      │   │
│  │   │   - Query IAM stack outputs                  │      │   │
│  │   │   - Extract 32 ARNs                          │      │   │
│  │   └──────────────────────────────────────────────┘      │   │
│  │              │                                            │   │
│  │              ▼                                            │   │
│  │   ┌──────────────────────────────────────────────┐      │   │
│  │   │ local.iam_parameters = { ... }               │      │   │
│  │   │   - Transform outputs to parameters          │      │   │
│  │   │   - Remove "Arn" suffix from names           │      │   │
│  │   └──────────────────────────────────────────────┘      │   │
│  │                                                           │   │
│  └───────────────────────────────────────────────────────────┘  │
│                      │                                           │
│                      ▼                                           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ aws_cloudformation_stack "stack" (Application)          │   │
│  │   parameters = merge(                                   │   │
│  │     var.parameters,                                     │   │
│  │     local.iam_parameters,  # 32 ARNs or empty map      │   │
│  │     { VPC, DBUrl, ... }    # Infrastructure params     │   │
│  │   )                                                     │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                    AWS CloudFormation                            │
│                                                                   │
│  ┌──────────────────────┐      ┌──────────────────────┐        │
│  │   IAM Stack          │      │   Application Stack  │        │
│  │   (quilt-prod-iam)   │─────▶│   (quilt-prod)       │        │
│  │                      │ ARNs │                      │        │
│  │  - 24 IAM Roles      │      │  - Lambda Functions  │        │
│  │  - 8 IAM Policies    │      │  - ECS Services      │        │
│  │  - 32 Outputs        │      │  - API Gateway       │        │
│  └──────────────────────┘      │  - 32 IAM Parameters │        │
│                                 └──────────────────────┘        │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow Specifications

### Flow 1: Template Preparation (Customer Workflow)

**WHAT**: Customer prepares CloudFormation templates for deployment

**Steps**:

1. **Obtain or create monolithic template**
   - Source: Customer's existing template or Quilt reference template
   - Format: Single YAML file with inline IAM resources

2. **Run split script**
   - Tool: `/Users/ernest/GitHub/scripts/iam-split/split_iam.py`
   - Input: Monolithic template
   - Output: Two templates (IAM + Application)
   - Validation: Script checks for circular dependencies

3. **Review split output**
   - Customer validates IAM template has all required resources
   - Customer validates application template references are transformed
   - Customer validates parameter definitions are correct

4. **Upload to S3**
   - IAM template: `s3://quilt-templates-{name}/quilt-iam.yaml`
   - App template: `s3://quilt-templates-{name}/quilt-app.yaml`
   - Bucket must be accessible to Terraform execution role

**Success Criteria**:

- ✅ Split script completes without errors
- ✅ Both templates are syntactically valid YAML
- ✅ IAM template has 32 outputs
- ✅ App template has 32 parameters
- ✅ Templates uploaded to correct S3 locations

**Failure Modes**:

- Split script detects unresolvable circular dependencies
- Template validation fails (invalid YAML, invalid CloudFormation)
- S3 upload fails (permissions, bucket doesn't exist)

**Recovery**:

- Fix circular dependencies in monolithic template
- Fix YAML syntax errors
- Fix S3 bucket permissions or create bucket

### Flow 2: IAM Stack Deployment (Terraform → CloudFormation)

**WHAT**: Terraform deploys IAM CloudFormation stack when external IAM pattern active

**Trigger**: `terraform apply` with `var.iam_template_url` set

**Steps**:

1. **Module instantiation**
   - Terraform evaluates `count = var.iam_template_url != null ? 1 : 0`
   - Result: IAM module created

2. **CloudFormation stack creation**
   - Terraform calls `aws_cloudformation_stack` resource
   - CloudFormation downloads template from S3
   - CloudFormation validates template
   - CloudFormation creates IAM resources

3. **Resource creation**
   - CloudFormation creates 24 IAM roles
   - CloudFormation creates 8 IAM managed policies
   - CloudFormation creates 32 stack outputs

4. **Stack completion**
   - CloudFormation stack reaches `CREATE_COMPLETE`
   - Outputs are available via CloudFormation API

**Success Criteria**:

- ✅ IAM stack created successfully
- ✅ All 32 IAM resources exist in AWS
- ✅ All 32 outputs populated with valid ARNs
- ✅ Stack status is `CREATE_COMPLETE`

**Failure Modes**:

- Template URL inaccessible → CloudFormation cannot download template
- Template validation fails → CloudFormation rejects template
- IAM resource creation fails → CloudFormation rollback
- Naming conflicts → CloudFormation error

**Recovery**:

- Fix S3 permissions or upload template
- Fix template syntax/structure
- Fix IAM resource definitions
- Change resource names or delete conflicting resources

### Flow 3: Output Query (Terraform Data Source)

**WHAT**: Terraform queries IAM stack outputs and makes them available to application stack

**Trigger**: Data source evaluation during Terraform plan/apply

**Steps**:

1. **Data source instantiation**
   - Terraform evaluates `count = var.iam_template_url != null ? 1 : 0`
   - Data source created if external IAM pattern active

2. **Stack name resolution**
   - If `var.iam_stack_name` provided: use it
   - Else: use `${var.name}-iam`

3. **API query**
   - Terraform calls CloudFormation `DescribeStacks` API
   - CloudFormation returns stack details including outputs

4. **Output extraction**
   - Terraform reads `outputs` map from stack description
   - All 32 outputs must be present
   - Terraform validates ARN format

5. **Local value population**
   - Outputs transformed to `local.iam_parameters` map
   - ARN suffix removed from keys (e.g., `SearchHandlerRoleArn` → `SearchHandlerRole`)

**Success Criteria**:

- ✅ Stack found in CloudFormation
- ✅ All 32 outputs present in stack
- ✅ All outputs have valid ARN values
- ✅ Local map populated correctly

**Failure Modes**:

- Stack not found → Terraform error "Stack does not exist"
- Stack in failed state → Terraform error with stack status
- Missing outputs → Terraform error listing missing outputs
- Invalid ARN format → Terraform validation error

**Recovery**:

- Ensure IAM stack deployed successfully
- Fix IAM stack (update or recreate)
- Fix IAM template to include all required outputs
- Check output value format in CloudFormation

### Flow 4: Application Stack Deployment (Terraform → CloudFormation)

**WHAT**: Terraform deploys application CloudFormation stack with IAM parameters

**Trigger**: `terraform apply` after IAM stack complete (if external IAM) or immediately (if inline IAM)

**Steps**:

1. **Parameter merge**
   - Terraform merges parameters in priority order:
     1. User parameters (`var.parameters`) - highest priority
     2. IAM parameters (`local.iam_parameters`) - if external IAM
     3. Infrastructure parameters (VPC, DB, etc.) - auto-generated

2. **CloudFormation stack creation/update**
   - Terraform calls `aws_cloudformation_stack` resource
   - CloudFormation downloads application template from S3
   - CloudFormation validates template and parameters

3. **Parameter validation**
   - CloudFormation checks all required parameters provided
   - CloudFormation validates parameter patterns (ARN format)
   - CloudFormation validates parameter constraints

4. **Resource creation**
   - CloudFormation creates Lambda functions referencing IAM roles
   - CloudFormation creates ECS tasks referencing IAM roles
   - CloudFormation creates API Gateway referencing IAM roles
   - All IAM references use parameter values (ARNs)

5. **Stack completion**
   - CloudFormation stack reaches `CREATE_COMPLETE` or `UPDATE_COMPLETE`

**Success Criteria**:

- ✅ Application stack created/updated successfully
- ✅ All IAM role references resolved correctly
- ✅ Application services start successfully
- ✅ No permission errors at runtime

**Failure Modes**:

- Parameter mismatch → CloudFormation validation error
- Missing IAM parameter → CloudFormation error "Missing required parameter"
- Invalid ARN → CloudFormation validation error
- IAM role lacks permissions → Runtime errors in application

**Recovery**:

- Fix parameter names in application template
- Ensure all required IAM parameters passed
- Fix ARN format in IAM stack outputs
- Update IAM role policies with required permissions

### Flow 5: Stack Updates (Ongoing Operations)

**WHAT**: Terraform handles updates to IAM and/or application stacks

**Scenarios**:

#### Scenario A: IAM Stack Update (Policy Changes)

**Trigger**: IAM template changes (policy modifications)

**Steps**:

1. Customer updates IAM template in S3
2. Customer runs `terraform apply`
3. Terraform detects IAM module input change
4. IAM CloudFormation stack updates
5. IAM policies updated in-place
6. Application stack unaffected (ARNs unchanged)

**Impact**: No application downtime

#### Scenario B: IAM Stack Update (Resource Replacement)

**Trigger**: IAM template changes requiring resource recreation

**Steps**:

1. Customer updates IAM template in S3
2. Customer runs `terraform apply`
3. Terraform detects IAM module input change
4. CloudFormation determines resources must be replaced
5. CloudFormation creates new resources with new ARNs
6. CloudFormation updates stack outputs
7. Terraform detects output changes in data source
8. Terraform propagates ARN changes to application stack parameters
9. Application stack updates with new ARNs
10. Application services restart with new IAM roles

**Impact**: Possible brief service disruption during application stack update

#### Scenario C: Application Stack Update (No IAM Changes)

**Trigger**: Application template or infrastructure changes

**Steps**:

1. Customer updates application template or Terraform variables
2. Customer runs `terraform apply`
3. Terraform detects application stack parameter/template changes
4. Application CloudFormation stack updates
5. IAM stack unaffected

**Impact**: Depends on application changes (service restart, etc.)

#### Scenario D: Infrastructure Update (VPC, DB, etc.)

**Trigger**: Infrastructure module changes

**Steps**:

1. Customer modifies infrastructure variables
2. Customer runs `terraform apply`
3. Terraform updates infrastructure modules
4. Terraform propagates new values to application stack parameters
5. Application stack updates with new infrastructure values
6. IAM stack unaffected

**Impact**: Depends on infrastructure changes (possible significant downtime)

**Success Criteria**:

- ✅ Updates apply in correct dependency order
- ✅ State remains consistent after updates
- ✅ Rollback works correctly on failures

**Failure Modes**:

- IAM stack update fails → application stack not updated (safe)
- Application stack update fails → may have inconsistent state
- Concurrent updates → potential race conditions
- CloudFormation exports in use → cannot delete/replace IAM stack

**Recovery**:

- Investigate CloudFormation stack events for root cause
- Rollback IAM stack if needed
- Retry application stack update
- Ensure no manual changes to stacks outside Terraform

### Flow 6: Stack Deletion (Teardown)

**WHAT**: Terraform destroys all infrastructure in correct order

**Trigger**: `terraform destroy`

**Steps**:

1. **Dependency analysis**
   - Terraform determines deletion order based on dependencies
   - Application stack must be deleted before IAM stack

2. **Application stack deletion**
   - Terraform deletes application CloudFormation stack
   - CloudFormation stops all services
   - CloudFormation deletes all application resources
   - CloudFormation removes parameter references to IAM ARNs

3. **IAM stack deletion** (if external IAM pattern)
   - Terraform deletes IAM CloudFormation stack
   - CloudFormation checks if exports are still in use
   - CloudFormation deletes all IAM resources
   - CloudFormation removes stack outputs

4. **Infrastructure deletion**
   - Terraform deletes infrastructure modules (VPC, DB, ElasticSearch)

**Success Criteria**:

- ✅ All resources deleted in correct order
- ✅ No orphaned resources
- ✅ Terraform state cleared

**Failure Modes**:

- Application stack deletion fails → IAM stack cannot be deleted
- IAM exports still in use → CloudFormation blocks IAM stack deletion
- Resources in use → CloudFormation rollback
- Manual resource modifications → Terraform cannot delete

**Recovery**:

- Fix application stack issues and retry
- Manually identify and remove export dependencies
- Stop services manually and retry
- Manually delete resources then import or ignore in Terraform

## Integration Contracts

### Contract 1: Split Script → CloudFormation Templates

**Provider**: Split script (`split_iam.py`)
**Consumer**: CloudFormation (via Terraform modules)

**Contract Specifications**:

**IAM Template Must**:

- Contain all 24 IAM roles identified in `config.yaml`
- Contain all 8 IAM managed policies identified in `config.yaml`
- NOT contain resource-specific policies (bucket policies, queue policies)
- NOT reference application resources (queues, buckets, Lambda functions)
- Output ARN for every IAM role and policy (32 outputs total)
- Use CloudFormation exports for all outputs
- Export names: `${AWS::StackName}-{ResourceName}Arn`

**Application Template Must**:

- Define parameter for every IAM role and policy (32 parameters total)
- Parameter names match IAM resource names (without "Arn" suffix)
- Parameter types all `String`
- Parameter validation patterns: ARN regex
- Use `!Ref` to reference IAM parameters (not `!GetAtt`)
- NOT define inline IAM resources for roles/policies being externalized

**Validation**:

- Split script validates circular dependencies before split
- Split script validates all `!GetAtt` references transformed
- Split script validates parameter/output name consistency

### Contract 2: IAM Module → CloudFormation IAM Template

**Provider**: IAM module (`modules/iam/`)
**Consumer**: CloudFormation IAM template

**Contract Specifications**:

**IAM Module Provides**:

- CloudFormation stack deployment
- Parameter passing capability
- Tag propagation
- Output extraction

**IAM Template Expects**:

- Optional parameters for customization
- Standard CloudFormation execution environment
- `CAPABILITY_NAMED_IAM` capability granted

**IAM Module Expects from Template**:

- Valid CloudFormation syntax
- All 32 outputs defined with specific names
- Output values are valid IAM ARNs
- Exports follow naming convention

**Validation**:

- CloudFormation validates template syntax
- Terraform validates output presence via data source
- Terraform validates ARN format via pattern matching

### Contract 3: Quilt Module → IAM Module

**Provider**: Quilt module (`modules/quilt/`)
**Consumer**: IAM module (`modules/iam/`)

**Contract Specifications**:

**Quilt Module Provides to IAM Module**:

- `name`: Base name for IAM stack
- `template_url`: S3 HTTPS URL of IAM template
- `parameters`: Map of CloudFormation parameters
- `tags`: Map of tags to apply

**IAM Module Provides to Quilt Module**:

- 32 ARN outputs (24 roles + 8 policies)
- `stack_id`: IAM stack ID
- `stack_name`: IAM stack name

**Dependencies**:

- IAM module completes before application stack deployment
- IAM module outputs available via module outputs
- IAM stack outputs also available via data source

**Validation**:

- Terraform validates module inputs (variable validation)
- Terraform ensures dependency order via implicit dependencies
- Terraform validates outputs are available

### Contract 4: Quilt Module → CloudFormation Application Template

**Provider**: Quilt module
**Consumer**: CloudFormation application template

**Contract Specifications**:

**Quilt Module Provides to App Template**:

- **External IAM Pattern**:
  - 32 IAM parameters (role/policy ARNs)
  - Infrastructure parameters (VPC, DB, etc.)
  - User-provided parameters
- **Inline IAM Pattern**:
  - Infrastructure parameters only
  - User-provided parameters
  - NO IAM parameters

**App Template Expects from Quilt Module**:

- **If split template**: All 32 IAM parameters provided
- **If monolithic template**: No IAM parameters provided
- Infrastructure parameters always provided
- Parameter values match expected formats

**Validation**:

- CloudFormation validates parameters against template definition
- CloudFormation validates parameter patterns (ARN format)
- CloudFormation validates required parameters present

### Contract 5: Customer Workflow → Terraform

**Provider**: Customer
**Consumer**: Terraform Quilt module

**Contract Specifications**:

**Customer Must Provide**:

- **For External IAM**:
  - Split IAM template uploaded to S3
  - Split application template uploaded to S3
  - `var.iam_template_url` set to IAM template S3 URL
  - `var.template_url` set to app template S3 URL (or use default)
- **For Inline IAM**:
  - Monolithic application template uploaded to S3
  - `var.iam_template_url` left as `null` (default)
  - `var.template_url` set to app template S3 URL (or use default)

**Customer Can Optionally Provide**:

- `var.iam_stack_name`: Override IAM stack name
- `var.iam_parameters`: Parameters for IAM template
- `var.iam_tags`: Additional tags for IAM stack

**Terraform Expects from Customer**:

- Templates are pre-split (external IAM) or monolithic (inline IAM)
- Templates uploaded to accessible S3 locations
- S3 bucket exists and Terraform has permissions
- Consistent pattern choice (don't mix split and monolithic templates)

**Validation**:

- Terraform validates variable inputs (URL format, etc.)
- CloudFormation validates templates during deployment
- Customer responsible for template correctness

## Error Handling Specifications

### Error Category 1: Template Preparation Errors

**Scenario**: Split script fails or produces invalid templates

**Detection**: Split script exits with error

**Error Messages**:

- "Circular dependency detected: Role X references Queue Y"
- "Output missing in IAM template: SearchHandlerRoleArn"
- "Parameter missing in app template: SearchHandlerRole"

**Recovery Actions**:

1. Fix circular dependencies in monolithic template
2. Ensure split script configuration includes all required resources
3. Re-run split script
4. Validate output templates

**Prevention**:

- Use split script configuration (`config.yaml`) correctly
- Review split script output before deployment
- Test templates with CloudFormation validation

### Error Category 2: IAM Stack Deployment Errors

**Scenario**: IAM CloudFormation stack creation/update fails

**Detection**: CloudFormation returns error status

**Error Messages**:

- "Template URL does not exist: https://..."
- "Role name already in use: arn:aws:iam::123456789012:role/..."
- "Invalid template property: ..."

**Recovery Actions**:

1. Check S3 bucket permissions and template existence
2. Delete conflicting IAM resources or change names
3. Fix template syntax errors
4. Retry deployment

**Prevention**:

- Upload templates to S3 before running Terraform
- Use unique IAM resource names per deployment
- Validate templates with `aws cloudformation validate-template`

### Error Category 3: Output Query Errors

**Scenario**: Terraform cannot query IAM stack or outputs missing

**Detection**: Terraform data source query fails

**Error Messages**:

- "Stack not found: quilt-prod-iam"
- "Stack output missing: SearchHandlerRoleArn"
- "Stack in failed state: ROLLBACK_COMPLETE"

**Recovery Actions**:

1. Verify IAM stack exists and is in successful state
2. Check IAM stack name matches expected name
3. Fix IAM stack (update or recreate)
4. Ensure IAM template has all required outputs

**Prevention**:

- Deploy IAM stack before application stack
- Use consistent stack naming
- Ensure IAM template has all 32 outputs

### Error Category 4: Application Stack Deployment Errors

**Scenario**: Application CloudFormation stack fails due to IAM parameter issues

**Detection**: CloudFormation validation or deployment error

**Error Messages**:

- "Parameter 'SearchHandlerRole' is required but not provided"
- "Parameter 'SearchHandlerRole' does not match pattern '^arn:aws:iam::...'"
- "Resource handler returned message: 'Role arn:aws:iam::... does not exist'"

**Recovery Actions**:

1. Verify IAM parameters passed correctly from Terraform
2. Check parameter names match between IAM outputs and app parameters
3. Verify IAM stack outputs have valid ARNs
4. Ensure IAM roles exist in AWS

**Prevention**:

- Use split script to generate parameter definitions
- Validate IAM stack outputs before deploying app stack
- Test with small deployment first

### Error Category 5: Update Propagation Errors

**Scenario**: IAM stack updates don't propagate to application stack correctly

**Detection**: Application services fail with permission errors after IAM update

**Error Messages**:

- Runtime errors in application logs
- "AccessDenied" errors from AWS services
- "Invalid IAM role ARN" in ECS task failures

**Recovery Actions**:

1. Verify IAM stack outputs reflect latest ARNs
2. Check if application stack parameters updated
3. Manually update application stack if needed
4. Restart application services if necessary

**Prevention**:

- Use Terraform for all updates (avoid manual changes)
- Review Terraform plan before applying updates
- Test IAM changes in non-production first

### Error Category 6: Stack Deletion Errors

**Scenario**: Cannot delete IAM stack due to export dependencies

**Detection**: CloudFormation returns error on stack deletion

**Error Messages**:

- "Export quilt-prod-iam-SearchHandlerRoleArn is still imported by stack quilt-prod"
- "Cannot delete stack while resources are in use"

**Recovery Actions**:

1. Delete application stack first (respects dependency order)
2. Use Terraform destroy (handles order automatically)
3. If manual deletion needed, delete in reverse order

**Prevention**:

- Always use Terraform destroy (not manual deletion)
- Delete application stack before IAM stack
- Don't mix Terraform and manual operations

## Quality Gates

### Gate 1: Template Validation

**WHEN**: After split script completes, before upload to S3

**WHAT**: Validate CloudFormation templates are syntactically correct

**CHECKS**:

```bash
# Validate IAM template
aws cloudformation validate-template \
  --template-body file://quilt-iam.yaml

# Validate application template
aws cloudformation validate-template \
  --template-body file://quilt-app.yaml
```

**SUCCESS CRITERIA**:

- ✅ Both templates pass CloudFormation validation
- ✅ No syntax errors
- ✅ All referenced parameters exist

**FAILURE**: Do not proceed to deployment

### Gate 2: IAM Stack Deployment

**WHEN**: After IAM module creates CloudFormation stack

**WHAT**: Verify IAM stack deployed successfully

**CHECKS**:

- Stack status is `CREATE_COMPLETE` or `UPDATE_COMPLETE`
- All 32 IAM resources exist in AWS
- All 32 stack outputs populated
- All outputs have valid ARN format

**SUCCESS CRITERIA**:

- ✅ Stack in successful state
- ✅ All resources created
- ✅ All outputs available

**FAILURE**: Do not proceed to application stack deployment

### Gate 3: Output Query

**WHEN**: After IAM stack deployment, before application stack deployment

**WHAT**: Verify all IAM outputs queryable by Terraform

**CHECKS**:

- Data source query succeeds
- All 32 outputs retrieved
- All ARNs match expected format
- Parameter transformation correct

**SUCCESS CRITERIA**:

- ✅ Data source returns all outputs
- ✅ ARN format validation passes
- ✅ Parameter map populated correctly

**FAILURE**: Do not proceed to application stack deployment

### Gate 4: Application Stack Deployment

**WHEN**: After application CloudFormation stack deployment

**WHAT**: Verify application stack deployed successfully

**CHECKS**:

- Stack status is `CREATE_COMPLETE` or `UPDATE_COMPLETE`
- All application resources created
- No CloudFormation errors
- Services start successfully

**SUCCESS CRITERIA**:

- ✅ Stack in successful state
- ✅ All resources created
- ✅ No runtime errors

**FAILURE**: Investigate CloudFormation events, fix issues, retry

### Gate 5: Runtime Validation

**WHEN**: After application services start

**WHAT**: Verify services have correct IAM permissions

**CHECKS**:

- Application logs show no permission errors
- Lambda functions execute successfully
- ECS tasks run without IAM errors
- API Gateway requests succeed

**SUCCESS CRITERIA**:

- ✅ No "AccessDenied" errors
- ✅ All services functional
- ✅ IAM roles have required permissions

**FAILURE**: Update IAM policies with missing permissions

## Non-Functional Integration Requirements

### Performance

**Requirement**: End-to-end deployment time comparable to inline IAM pattern

**Targets**:

- Template split: < 30 seconds
- IAM stack deployment: < 5 minutes
- Output query: < 30 seconds
- Application stack deployment: < 15 minutes (unchanged)
- Total overhead: < 10% of inline IAM deployment time

**Measurement**: Time Terraform apply execution

### Reliability

**Requirement**: Consistent, repeatable deployments

**Targets**:

- Deployment success rate: > 95% (excluding customer template errors)
- Rollback success rate: 100%
- State consistency: No manual intervention required

**Measurement**: Track deployment outcomes over time

### Usability

**Requirement**: Clear workflows and error messages

**Targets**:

- Workflow documented with examples
- Error messages include remediation steps
- Common issues covered in troubleshooting guide
- Split script output explained

**Measurement**: Customer feedback and support tickets

### Security

**Requirement**: Maintain security posture

**Targets**:

- IAM roles follow least-privilege principle
- S3 templates protected with appropriate permissions
- CloudFormation stacks tagged for auditing
- No secrets in Terraform state

**Measurement**: Security audit findings

## Success Criteria

### Integration Success

- ✅ All components integrate correctly
- ✅ Data flows from customer to AWS without manual intervention
- ✅ Error handling works at each integration point
- ✅ Quality gates prevent deployment of invalid configurations

### Workflow Success

- ✅ Customer workflow documented and tested
- ✅ Split script produces valid templates
- ✅ Templates deploy successfully via Terraform
- ✅ Updates and deletions work correctly

### Reliability Success

- ✅ Deployments are repeatable
- ✅ State remains consistent across updates
- ✅ Failures are detectable and recoverable
- ✅ Rollback scenarios work correctly

### Documentation Success

- ✅ End-to-end workflow documented
- ✅ Error scenarios and recovery documented
- ✅ Quality gates explained
- ✅ Examples provided for common scenarios

## Out of Scope

- ❌ Automated end-to-end testing framework
- ❌ Monitoring and alerting integration
- ❌ Multi-region deployment orchestration
- ❌ Blue-green deployment patterns
- ❌ Automated rollback on failures
- ❌ Integration with CI/CD pipelines
- ❌ Custom validation beyond CloudFormation

## Open Questions

None. All integration patterns and workflows have been specified.

## References

- IAM Module Specification: [03-spec-iam-module.md](03-spec-iam-module.md)
- Quilt Module Specification: [04-spec-quilt-module.md](04-spec-quilt-module.md)
- Analysis Document: [02-analysis.md](02-analysis.md)
- Requirements Document: [01-requirements.md](01-requirements.md)
- Split Script: `/Users/ernest/GitHub/scripts/iam-split/split_iam.py`
- CloudFormation Stack Docs: <https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/stacks.html>
- Terraform Module Composition: <https://www.terraform.io/docs/language/modules/composition.html>

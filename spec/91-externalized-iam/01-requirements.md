# Requirements: Externalized IAM Resources

**Issue**: [#91 - externalized IAM](https://github.com/quiltdata/quilt-infrastructure/issues/91)

**Date**: 2025-11-20

**Branch**: 91-externalized-iam

## Problem Statement

Enterprise customers with strict IAM governance policies require the ability to deploy IAM resources separately from application infrastructure. Current Terraform module implementation combines all resources in a single CloudFormation stack, preventing security teams from managing IAM independently while allowing application teams to deploy infrastructure.

## User Stories

### Story 1: Security Team IAM Management

**As a** security team member responsible for IAM governance
**I want** to deploy and manage IAM roles and policies in a separate CloudFormation stack
**So that** I can maintain control over identity and access management while enabling application teams to deploy infrastructure

### Story 2: Application Team Infrastructure Deployment

**As an** application team member deploying Quilt infrastructure
**I want** to reference pre-existing IAM resources from a separately deployed IAM stack
**So that** I can deploy application infrastructure without requiring IAM management permissions

### Story 3: Backward Compatibility

**As an** existing Quilt customer using the current single-stack architecture
**I want** the module to continue working with inline IAM resources
**So that** I am not forced to migrate to the two-stack architecture unless my organization requires it

### Story 4: Clear Documentation

**As a** new Quilt customer evaluating deployment options
**I want** clear examples demonstrating both single-stack and two-stack deployment patterns
**So that** I can choose the appropriate architecture for my organization's security policies

## Acceptance Criteria

1. **IAM Module Creation**
   - A new `modules/iam/` Terraform module exists that deploys only IAM resources via CloudFormation
   - The IAM module creates approximately 20 IAM roles and 4 managed policies
   - The IAM stack exports all role and policy ARNs via CloudFormation outputs
   - The IAM module accepts configuration parameters for customization

2. **Application Module Enhancement**
   - The `modules/quilt/` module accepts an optional `iam_stack_name` variable
   - When `iam_stack_name` is provided, the module queries IAM stack outputs via CloudFormation data source
   - IAM ARNs from the external stack are passed as parameters to the application CloudFormation template
   - When `iam_stack_name` is not provided, the module behaves as it currently does (inline IAM)

3. **Backward Compatibility**
   - Existing deployments using inline IAM continue to function without modification
   - The default behavior (no `iam_stack_name` provided) remains unchanged
   - No breaking changes to the public module API

4. **IAM Resources Coverage**
   - All 24 IAM roles are included in the IAM module:
     - SearchHandlerRole, EsIngestRole, ManifestIndexerRole, AccessCountsRole, PkgEventsRole
     - DuckDBSelectLambdaRole, PkgPushRole, PackagerRole, AmazonECSTaskExecutionRole, ManagedUserRole
     - MigrationLambdaRole, TrackingCronRole, ApiRole, TimestampResourceHandlerRole, TabulatorRole
     - TabulatorOpenQueryRole, IcebergLambdaRole, T4BucketReadRole, T4BucketWriteRole, S3ProxyRole
     - S3SNSToEventBridgeRole, S3HashLambdaRole, S3CopyLambdaRole, S3LambdaRole
   - All 8 managed policies are included in the IAM module:
     - BucketReadPolicy, BucketWritePolicy, RegistryAssumeRolePolicy, ManagedUserRoleBasePolicy
     - UserAthenaNonManagedRolePolicy, UserAthenaManagedRolePolicy, TabulatorOpenQueryPolicy, T4DefaultBucketReadPolicy

5. **Documentation and Examples**
   - Example configuration demonstrating the two-stack deployment pattern
   - Example configuration demonstrating the traditional single-stack pattern
   - Clear documentation explaining when to use each approach
   - Migration guide for customers wanting to transition from single-stack to two-stack

6. **Testing and Validation**
   - Both deployment patterns can be successfully deployed
   - IAM resources in the external stack are correctly referenced by the application stack
   - CloudFormation parameter passing works correctly
   - All existing tests continue to pass

## High-Level Implementation Approach

The solution will introduce a modular architecture that separates IAM concerns from application infrastructure:

1. **Create IAM Module**: Extract IAM resource definitions into a standalone Terraform module that outputs resource ARNs via CloudFormation exports

2. **Enhance Application Module**: Modify the main Quilt module to optionally consume IAM ARNs from an external stack via data sources and parameters

3. **Maintain Compatibility**: Use conditional logic to preserve existing single-stack behavior when IAM stack is not specified

4. **Provide Examples**: Document both deployment patterns with clear guidance on selection criteria

## Success Criteria

1. **Functional**: Both single-stack and two-stack deployments work successfully
2. **Secure**: IAM resources can be managed by dedicated security teams with appropriate permissions
3. **Compatible**: Existing customers are not impacted by the changes
4. **Documented**: Clear examples and guidance enable customers to choose the right approach
5. **Maintainable**: Code structure supports both patterns without excessive complexity

## Open Questions

1. **IAM Module Configuration**: What configuration parameters should the IAM module accept to allow customization of IAM resources (e.g., permission boundaries, custom trust policies)?

2. **CloudFormation Export Naming**: What naming convention should be used for CloudFormation exports to avoid conflicts between multiple deployments in the same region/account?

3. **Permissions Separation**: Should the IAM module include separate outputs for different permission levels (e.g., read-only vs. read-write roles) to support different application stack configurations?

4. **Migration Path**: Do we need tooling to help existing customers migrate from single-stack to two-stack architecture, or is documentation sufficient?

5. **Version Dependencies**: Should there be version alignment between IAM and application stacks to prevent incompatibilities?

6. **Region Constraints**: CloudFormation exports are region-specific. How should we document or handle multi-region deployments?

7. **Testing Strategy**: What automated tests should verify the IAM/application stack integration beyond manual deployment validation?

8. **ElasticSearch/OpenSearch**: Are there specific IAM considerations for the ElasticSearch/OpenSearch components that require special handling?

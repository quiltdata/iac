# Analysis: Current Architecture and Implementation Patterns

**Issue**: [#91 - externalized IAM](https://github.com/quiltdata/quilt-infrastructure/issues/91)

**Date**: 2025-11-20

**Branch**: 91-externalized-iam

**References**: [01-requirements.md](01-requirements.md)

## Executive Summary

This analysis examines the current Quilt infrastructure deployment architecture to understand how IAM resources are managed and identify the technical challenges in implementing the externalized IAM feature. The analysis reveals a hybrid Terraform-CloudFormation architecture where IAM resources are currently embedded within a monolithic CloudFormation template, creating barriers for enterprise customers with strict IAM governance requirements.

## Current System Architecture

### 1. Hybrid Infrastructure Management

The Quilt infrastructure uses a **two-layer deployment model**:

#### Layer 1: Terraform-Managed Infrastructure

**Location**: [`/modules/quilt/main.tf`](../../modules/quilt/main.tf)

**Responsibilities**:
- VPC networking (via `modules/vpc/`)
- RDS PostgreSQL database (via `modules/db/`)
- ElasticSearch domain (via `modules/search/`)
- S3 bucket for CloudFormation template storage
- CloudFormation stack orchestration

**Key Pattern**: Terraform creates foundational infrastructure and passes connection details to CloudFormation:

```hcl
# From modules/quilt/main.tf:89-143
resource "aws_cloudformation_stack" "stack" {
  name         = var.name
  template_url = local.template_url

  parameters = merge(
    var.parameters,
    {
      VPC               = module.vpc.vpc_id
      Subnets           = join(",", module.vpc.private_subnets)
      DBUrl             = format("postgresql://%s:%s@%s/%s", ...)
      SearchDomainArn   = module.search.search.arn
      # ... 10+ other auto-generated parameters
    }
  )

  capabilities = ["CAPABILITY_NAMED_IAM"]
}
```

**Critical Observation**: The `CAPABILITY_NAMED_IAM` capability indicates CloudFormation creates IAM resources with custom names.

#### Layer 2: CloudFormation-Managed Application Stack

**Location**: Customer-provided YAML template (e.g., `syngenta-nonprod.yaml`, `quilt.yaml`)

**Responsibilities**:
- IAM roles (24 roles)
- IAM managed policies (8 policies)
- Lambda functions
- ECS services
- API Gateway
- Application-specific S3 buckets and SQS queues
- Load balancers and target groups

**Template Size**: ~4,950 lines (monolithic)

### 2. CloudFormation Template Structure

#### Current Monolithic Architecture

**Example**: `syngenta-nonprod.yaml` (4,952 lines)

**Structure**:
```yaml
Description: Quilt Data catalog and services
Metadata:
  AWS::CloudFormation::Interface:
    ParameterGroups:
      - Label: Administrator catalog credentials
      - Label: Web catalog
      - Label: Database
      - Label: Network settings
      - Label: Web catalog authentication
      - Label: Beta features
      # NO IAM parameter group currently

Conditions:
  ChunkedChecksumsEnabled: ...
  QuratorEnabled: ...
  SingleSignOn: ...
  # 20+ conditions

Mappings:
  PartitionConfig:
    aws:
      PrimaryRegion: us-east-1
      AccountId: '730278974607'

Parameters:
  # Network parameters (from Terraform)
  VPC: {Type: String}
  Subnets: {Type: CommaDelimitedList}
  DBUrl: {Type: String}
  SearchDomainArn: {Type: String}
  # 30+ other parameters
  # NO IAM ARN parameters currently

Resources:
  # IAM Roles inline (lines 499-4837)
  SearchHandlerRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument: ...
      ManagedPolicyArns:
        - !Ref BucketReadPolicy  # Resource reference
      Policies: [...]

  # Lambda Functions
  SearchHandler:
    Type: AWS::Lambda::Function
    Properties:
      Role: !GetAtt 'SearchHandlerRole.Arn'  # Gets ARN from resource

  # ECS Tasks
  RegistryTaskDefinition:
    Type: AWS::ECS::TaskDefinition
    Properties:
      ExecutionRoleArn: !GetAtt 'AmazonECSTaskExecutionRole.Arn'
      TaskRoleArn: !GetAtt 'AmazonECSTaskExecutionRole.Arn'

Outputs:
  RegistryRoleARN:
    Value: !GetAtt 'AmazonECSTaskExecutionRole.Arn'
```

**Key Characteristics**:
1. **Inline IAM Resources**: All IAM roles/policies defined as CloudFormation resources
2. **GetAtt References**: `!GetAtt 'RoleName.Arn'` used throughout to reference role ARNs
3. **Resource Dependencies**: IAM resources reference application resources (circular dependencies)
4. **Single Stack**: Everything deployed as one atomic unit

### 3. IAM Resources Inventory

Based on analysis of the split converter output and configuration:

#### IAM Roles (24 total)

**Location**: `config.yaml:6-30`

| Role Name | Purpose | Circular Dependencies |
|-----------|---------|----------------------|
| `SearchHandlerRole` | Search handler Lambda | References `IndexerQueue`, `ManifestIndexerQueue` |
| `EsIngestRole` | ElasticSearch ingest Lambda | References `EsIngestQueue`, `EsIngestBucket` |
| `ManifestIndexerRole` | Manifest indexer Lambda | References `ManifestIndexerQueue` |
| `AccessCountsRole` | Access counts Lambda | None identified |
| `PkgEventsRole` | Package events Lambda | None identified |
| `DuckDBSelectLambdaRole` | DuckDB select Lambda | None identified |
| `PkgPushRole` | Package push service | None identified |
| `PackagerRole` | Packager service | None identified |
| `AmazonECSTaskExecutionRole` | ECS task execution | Complex policies |
| `ManagedUserRole` | Managed user role | None identified |
| `MigrationLambdaRole` | Migration Lambda | None identified |
| `TrackingCronRole` | Tracking cron Lambda | None identified |
| `ApiRole` | API Gateway Lambda | None identified |
| `TimestampResourceHandlerRole` | Timestamp handler | None identified |
| `TabulatorRole` | Tabulator service | None identified |
| `TabulatorOpenQueryRole` | Tabulator open query | None identified |
| `IcebergLambdaRole` | Iceberg Lambda | None identified |
| `T4BucketReadRole` | T4 bucket read-only | None identified |
| `T4BucketWriteRole` | T4 bucket write | None identified |
| `S3ProxyRole` | S3 proxy service | None identified |
| `S3LambdaRole` | S3 Lambda functions | None identified |
| `S3SNSToEventBridgeRole` | SNS to EventBridge | None identified |
| `S3HashLambdaRole` | S3 hash Lambda | None identified |
| `S3CopyLambdaRole` | S3 copy Lambda | None identified |

#### IAM Managed Policies (8 total)

**Location**: `config.yaml:33-41`

| Policy Name | Purpose | Used By |
|-------------|---------|---------|
| `BucketReadPolicy` | S3 read access | Multiple roles |
| `BucketWritePolicy` | S3 write access | Multiple roles |
| `RegistryAssumeRolePolicy` | Registry assume role | Registry-related roles |
| `ManagedUserRoleBasePolicy` | Base managed user policy | ManagedUserRole |
| `UserAthenaNonManagedRolePolicy` | Athena for non-managed | User roles |
| `UserAthenaManagedRolePolicy` | Athena for managed | User roles |
| `TabulatorOpenQueryPolicy` | Tabulator open query | TabulatorOpenQueryRole |
| `T4DefaultBucketReadPolicy` | T4 default read | T4 roles |

#### Resource-Specific Policies (NOT to extract)

**Location**: `config.yaml:44-55`

These policies are tightly coupled to application resources and must remain in the application stack:

- `EsIngestBucketPolicy` - Grants permissions on `EsIngestBucket` resource
- `EsIngestQueuePolicy` - Grants permissions on `EsIngestQueue` resource
- `CloudTrailBucketPolicy` - Grants permissions on `CloudTrailBucket` resource
- `AnalyticsBucketPolicy` - Grants permissions on `AnalyticsBucket` resource
- `UserAthenaResultsBucketPolicy` - Grants permissions on `UserAthenaResultsBucket`
- `DuckDBSelectLambdaBucketPolicy` - Grants permissions on `DuckDBSelectLambdaBucket`
- `PackagerQueuePolicy` - Grants permissions on `PackagerQueue` resource
- `ServiceBucketPolicy` - Grants permissions on `ServiceBucket` resource
- `TabulatorBucketPolicy` - Grants permissions on `TabulatorBucket` resource
- `IcebergBucketPolicy` - Grants permissions on `IcebergBucket` resource
- `IcebergLambdaQueuePolicy` - Grants permissions on `IcebergLambdaQueue` resource

### 4. Reference Transformation Patterns

#### Current Pattern (Inline IAM)

```yaml
# IAM Role defined as resource
SearchHandlerRole:
  Type: AWS::IAM::Role
  Properties:
    AssumeRolePolicyDocument: ...
    ManagedPolicyArns:
      - !Ref 'BucketReadPolicy'  # References policy resource

# Lambda uses GetAtt to get ARN
SearchHandler:
  Type: AWS::Lambda::Function
  Properties:
    Role: !GetAtt 'SearchHandlerRole.Arn'
```

#### Target Pattern (Externalized IAM)

After split, the IAM stack exports:
```yaml
# IAM Stack Output
Outputs:
  SearchHandlerRoleArn:
    Description: ARN of SearchHandlerRole
    Value: !GetAtt SearchHandlerRole.Arn
    Export:
      Name: !Sub '${AWS::StackName}-SearchHandlerRoleArn'
```

Application stack receives as parameter:
```yaml
# Application Stack Parameter
Parameters:
  SearchHandlerRole:
    Type: String
    MinLength: 1
    AllowedPattern: '^arn:aws:iam::[0-9]{12}:role\/[a-zA-Z0-9+=,.@_\-\/]+$'
    Description: ARN of the SearchHandlerRole

# Lambda uses Ref to get parameter value (ARN)
SearchHandler:
  Type: AWS::Lambda::Function
  Properties:
    Role: !Ref 'SearchHandlerRole'  # Now references parameter
```

**Transformation**: `!GetAtt 'RoleName.Arn'` → `!Ref 'RoleName'`

### 5. Existing IAM Split Tooling

**Location**: `/Users/ernest/GitHub/scripts/iam-split/`

A Python-based conversion tool already exists that demonstrates the IAM split pattern:

#### Tool Capabilities

**Source**: `split_iam.py` (830 lines)

**Features**:
- Comment preservation using `ruamel.yaml`
- Automatic reference transformation (`!GetAtt` → `!Ref`)
- Circular dependency detection
- Parameter generation with ARN validation patterns
- CloudFormation metadata updates
- AWS CLI validation integration
- Conversion reports

**Example Output**: The tool has successfully split `syngenta-nonprod.yaml` (4,952 lines):
- **IAM Stack**: 1,549 lines with 24 roles + 8 policies
- **App Stack**: 3,763 lines with IAM parameters

#### Key Insights from Split Output

**Observation**: The split template (`syngenta-nonprod-app.yaml`) demonstrates the target state:

```yaml
Metadata:
  AWS::CloudFormation::Interface:
    ParameterGroups:
      # ... existing groups ...
      - Label:
          default: IAM roles and policies
        Parameters:
          - AccessCountsRole
          - AmazonECSTaskExecutionRole
          - ApiRole
          - BucketReadPolicy
          - BucketWritePolicy
          # ... 24 roles + 8 policies alphabetically
```

**Parameter Structure** (example from output):
```yaml
Parameters:
  SearchHandlerRole:
    Type: String
    MinLength: 1
    AllowedPattern: '^arn:aws:iam::[0-9]{12}:role\/[a-zA-Z0-9+=,.@_\-\/]+$'
    Description: ARN of the SearchHandlerRole
```

## Current System Constraints and Limitations

### 1. Deployment Architecture Constraints

**Issue**: Single-stack atomic deployment
- **Impact**: Security teams cannot manage IAM independently
- **Blocker**: CloudFormation requires all IAM resources in the same stack as consumers
- **Evidence**: `modules/quilt/main.tf:98` - `capabilities = ["CAPABILITY_NAMED_IAM"]`

### 2. IAM Resource Coupling

**Issue**: Circular dependencies between IAM and application resources

**Examples from analysis**:

```yaml
# SearchHandlerRole references application resources
SearchHandlerRole:
  Policies:
    - PolicyName: sqs
      PolicyDocument:
        Statement:
          - Effect: Allow
            Action: [sqs:DeleteMessage, ...]
            Resource: !GetAtt 'IndexerQueue.Arn'  # App resource
```

**Affected Roles**:
- `SearchHandlerRole` → `IndexerQueue`, `ManifestIndexerQueue`
- `EsIngestRole` → `EsIngestQueue`, `EsIngestBucket`
- `ManifestIndexerRole` → `ManifestIndexerQueue`

**Resolution Strategy**: These roles can still be externalized by using parameter placeholders or wildcard resources in IAM policies.

### 3. CloudFormation Export Limitations

**Issue**: CloudFormation exports are region-specific and have naming constraints

**Constraints**:
- Export names must be unique within a region/account
- Cannot delete exports while they're imported by other stacks
- Export name format: `${AWS::StackName}-${ResourceName}Arn`

**Implication**: Naming convention must prevent collisions across multiple deployments.

### 4. Parameter Passing Complexity

**Current**: Terraform passes 10+ parameters to CloudFormation
**Future**: Will need to pass 32+ parameters (24 roles + 8 policies)

**Terraform parameter merge pattern**:
```hcl
parameters = merge(
  var.parameters,      # User-provided
  { ... }              # Auto-generated from modules
)
```

**Challenge**: Need to query IAM stack outputs and pass to application stack.

### 5. Template Management Complexity

**Current Pattern**:
- Customer provides single monolithic template
- Template stored in S3: `s3://{bucket}/quilt.yaml`
- CloudFormation stack references S3 URL

**New Pattern Required**:
- Two templates: IAM + Application
- IAM template deployed first
- Application template needs IAM stack name/outputs

**Storage Pattern Change**:
```
Current:  s3://quilt-templates-{name}/quilt.yaml
Proposed: s3://quilt-templates-{name}/quilt-iam.yaml
          s3://quilt-templates-{name}/quilt-app.yaml
```

## Architectural Gaps

### Gap 1: No IAM Module Exists

**Missing**: `modules/iam/` Terraform module
**Required Capabilities**:
- Deploy IAM CloudFormation stack
- Output role/policy ARNs
- Support customization via variables
- Handle IAM stack naming

### Gap 2: No IAM Stack Output Query Mechanism

**Missing**: Data source to query IAM stack outputs in `modules/quilt/`

**Required Pattern**:
```hcl
data "aws_cloudformation_stack" "iam" {
  count = var.iam_stack_name != null ? 1 : 0
  name  = var.iam_stack_name
}

locals {
  iam_role_arns = var.iam_stack_name != null ? {
    SearchHandlerRole = data.aws_cloudformation_stack.iam[0].outputs["SearchHandlerRoleArn"]
    # ... 31 more mappings
  } : {}
}
```

### Gap 3: No Conditional IAM Parameter Logic

**Missing**: Logic to conditionally pass IAM parameters only when external stack is used

**Required Pattern**:
```hcl
parameters = merge(
  var.parameters,
  local.iam_role_arns,  # Empty map if iam_stack_name == null
  { VPC = module.vpc.vpc_id, ... }
)
```

### Gap 4: No Template Preprocessing

**Issue**: Customer templates currently have inline IAM resources

**Options**:
1. **Customer provides pre-split templates** - Simple but requires customer work
2. **Terraform splits at deploy time** - Complex but transparent
3. **Separate tool for splitting** - Exists but not integrated

**Recommendation**: Option 1 (customer provides pre-split) with tooling support via the existing `split_iam.py` script.

### Gap 5: No Backward Compatibility Strategy

**Missing**: Migration path for existing deployments

**Considerations**:
- Existing stacks use inline IAM
- Cannot change IAM resource names without recreation
- Stack updates may fail if IAM resources are removed

**Required**: Clear guidance on when to use each pattern.

## Code Idioms and Conventions

### 1. Terraform Module Patterns

**Observation**: Consistent module structure across `vpc/`, `db/`, `search/`

**Pattern**:
```
modules/{name}/
  ├── main.tf       # Resources
  ├── variables.tf  # Inputs
  └── outputs.tf    # Outputs
```

**Convention**: New `modules/iam/` should follow this structure.

### 2. Variable Naming Convention

**Pattern**: Lowercase with underscores
```hcl
variable "db_instance_class"
variable "search_instance_type"
variable "create_new_vpc"
```

**Convention**: Use `iam_stack_name` for the new variable.

### 3. Resource Naming Convention

**Pattern**: Prefixed with module name variable
```hcl
resource "aws_db_instance" "db" {
  identifier = var.name
}

resource "aws_elasticsearch_domain" "search" {
  domain_name = var.name
}
```

**Convention**: IAM stack name should be `{var.name}-iam`.

### 4. Conditional Resource Creation

**Pattern**: Count-based conditionals
```hcl
module "vpc" {
  source = "../vpc"
  create_new_vpc = var.create_new_vpc
}
```

**Convention**: Use `count = var.iam_stack_name != null ? 1 : 0` for IAM data source.

### 5. Parameter Merging Pattern

**Pattern**: User parameters override defaults
```hcl
parameters = merge(
  var.parameters,       # User overrides
  { ... }              # Module-generated defaults
)
```

**Convention**: IAM parameters should merge after user parameters.

## Technical Debt and Challenges

### 1. Monolithic Template Size

**Current**: 4,952 lines in single file
**Challenge**: Large templates are difficult to maintain and validate
**Mitigation**: Split reduces app template to ~3,763 lines

### 2. Circular Dependencies

**Issue**: IAM roles reference application resources
**Impact**: Roles cannot be fully isolated without resource wildcards
**Example**: `SearchHandlerRole` references `IndexerQueue.Arn`

**Resolution Options**:
- Use wildcard resources in IAM policies
- Pass application resource ARNs as parameters to IAM stack (creates reverse dependency)
- Keep tightly-coupled roles in application stack

### 3. Parameter Explosion

**Current**: ~30 parameters
**Future**: ~62 parameters (30 existing + 32 IAM)
**Impact**: Increased complexity in parameter management
**Mitigation**: Parameter groups in CloudFormation UI help organize

### 4. CloudFormation Stack Dependencies

**Issue**: Application stack depends on IAM stack completion
**Impact**: Deployment orchestration becomes more complex
**Mitigation**: Terraform implicit dependencies via data source

### 5. Multi-Region Deployments

**Issue**: CloudFormation exports are region-specific
**Impact**: Each region needs separate IAM stack
**Challenge**: Export name collisions if same stack name used
**Mitigation**: Include region in export names or stack names

## Existing Solution Components

### Python Split Script

**Location**: `/Users/ernest/GitHub/scripts/iam-split/split_iam.py`

**Demonstrated Capabilities**:
- Successfully split a 4,952-line template
- Preserved comments and formatting
- Generated 32 parameters with validation
- Transformed 100+ `!GetAtt` references
- Created CloudFormation metadata parameter groups
- Detected circular dependencies

**Integration Opportunity**: This tool demonstrates the split pattern and could inform Terraform module design.

### Configuration-Driven Approach

**Location**: `/Users/ernest/GitHub/scripts/iam-split/config.yaml`

**Pattern**: Declarative configuration for resource extraction
```yaml
extraction:
  roles: [list of 24 roles]
  policies: [list of 8 policies]
  exclude_policies: [list of 11 resource policies]
```

**Insight**: Clear separation of concerns between IAM resources and resource-specific policies.

## Summary of Findings

### Current State Strengths

1. ✅ **Hybrid Architecture**: Clean separation between Terraform infrastructure and CloudFormation application
2. ✅ **Module Pattern**: Consistent, reusable module structure
3. ✅ **Parameter Passing**: Robust merge pattern for parameter management
4. ✅ **Existing Tooling**: Proven IAM split script demonstrates feasibility

### Current State Weaknesses

1. ❌ **Monolithic IAM**: All IAM resources embedded in application template
2. ❌ **No IAM Module**: Missing Terraform module for IAM stack deployment
3. ❌ **No Conditional Logic**: Cannot choose between inline and external IAM
4. ❌ **Circular Dependencies**: Some IAM roles tightly coupled to app resources
5. ❌ **Migration Complexity**: No clear path for existing deployments

### Key Technical Challenges

1. **Challenge**: Circular dependencies between IAM and application resources
   - **Impact**: HIGH - Affects 3 roles (SearchHandler, EsIngest, ManifestIndexer)
   - **Mitigation**: Use wildcard resources or keep roles in app stack

2. **Challenge**: CloudFormation export naming and region constraints
   - **Impact**: MEDIUM - Affects multi-region deployments
   - **Mitigation**: Stack naming convention with region/account prefix

3. **Challenge**: Parameter count increase (30 → 62 parameters)
   - **Impact**: MEDIUM - Complexity for users
   - **Mitigation**: Parameter groups and clear documentation

4. **Challenge**: Backward compatibility for existing deployments
   - **Impact**: MEDIUM - Migration risk for customers
   - **Mitigation**: Support both patterns, make external IAM optional

5. **Challenge**: Template management (1 template → 2 templates)
   - **Impact**: LOW - Solvable with clear examples
   - **Mitigation**: Documentation and split script tooling

## Next Steps

This analysis provides the foundation for the specifications document, which will define:
1. Desired end state architecture
2. Success criteria for IAM externalization
3. Integration points between Terraform and CloudFormation
4. API contracts for the new IAM module
5. Quality gates and validation criteria

## References

- Current module structure: [`/modules/quilt/`](../../modules/quilt/)
- Split script: `/Users/ernest/GitHub/scripts/iam-split/split_iam.py`
- Split config: `/Users/ernest/GitHub/scripts/iam-split/config.yaml`
- Example split output: `/Users/ernest/GitHub/scripts/iam-split/output/syngenta-nonprod-{iam,app}.yaml`
- IAM split design doc: `/Users/ernest/GitHub/scripts/iam-split/doc/01-design-iam-split.md`

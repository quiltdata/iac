# Deployment Script Fix: Use Quilt Module

## Problem

The `deploy/tf_deploy.py` script generates Terraform code that creates **raw CloudFormation stacks** directly, bypassing the `modules/quilt` module entirely. This means:

- ❌ No VPC creation via `modules/vpc`
- ❌ No RDS database via `modules/db`
- ❌ No OpenSearch via `modules/search`
- ❌ Just passes pre-existing infrastructure IDs to CloudFormation

## Required Architecture

```
tf_deploy.py → module "quilt" → [VPC, DB, Search, IAM (conditional), CloudFormation]
```

The script MUST generate Terraform that instantiates `module "quilt"` from `../../modules/quilt`, which handles all infrastructure creation.

## Key Requirements

### 1. Generate Module-Based Terraform

**Files to fix:**
- `deploy/lib/utils.py:_generate_main_tf()`
- `deploy/templates/external-iam.tf.j2` (delete and regenerate from code)
- `deploy/templates/inline-iam.tf.j2` (delete and regenerate from code)

**Generated code must look like:**

```hcl
module "quilt" {
  source = "../../modules/quilt"

  name          = var.name
  template_file = var.template_file

  # External IAM activation
  iam_template_url = var.iam_template_url  # null for inline, URL for external

  # Network config
  create_new_vpc = var.create_new_vpc
  vpc_id         = var.vpc_id
  # ... all other quilt module variables

  # DB config
  db_instance_class = var.db_instance_class
  # ... other db variables

  # Search config
  search_instance_type = var.search_instance_type
  # ... other search variables

  # CloudFormation parameters (merged with IAM outputs internally)
  parameters = {
    AdminEmail        = var.admin_email
    CertificateArnELB = var.certificate_arn
    QuiltWebHost      = var.quilt_web_host
    # ... other CFN parameters
  }
}
```

### 2. Variable Mapping

**The script must map config.json values to quilt module variables:**

- `config.region` → `var.aws_region` (provider config)
- `config.detected.vpcs[0].vpc_id` → `var.vpc_id`
- `config.detected.subnets[...]` → `var.intra_subnets`, `var.private_subnets`, `var.public_subnets`
- `config.detected.certificates[0].arn` → `var.certificate_arn`
- Database settings → `var.db_instance_class`, etc.
- Search settings → `var.search_instance_type`, etc.

### 3. External IAM Activation

**Pattern selection controls IAM behavior:**

```python
# In _generate_main_tf():
if pattern == "external-iam":
    # Set iam_template_url to S3 URL
    iam_template_url = f"https://{bucket}.s3.{region}.amazonaws.com/quilt-iam.yaml"
else:
    # inline-iam pattern
    iam_template_url = "null"  # Triggers inline IAM in quilt module
```

### 4. Template Files

**Two CloudFormation templates uploaded to S3:**

- `stable-iam.yaml` → uploaded as `quilt-iam.yaml`
- `stable-app.yaml` → uploaded as `quilt-app.yaml`

**The quilt module receives:**
- `template_file`: Path to local `stable-app.yaml` (for S3 upload)
- `iam_template_url`: S3 URL to `quilt-iam.yaml` (or null)

### 5. Outputs

**Must expose quilt module outputs:**

```hcl
output "stack_id" {
  value = module.quilt.stack.id
}

output "quilt_url" {
  value = "https://${var.quilt_web_host}"
}

# For external-iam pattern only:
output "iam_stack_name" {
  value = module.quilt.iam_stack_name
}

output "iam_outputs" {
  value = module.quilt.iam_outputs
}
```

## Critical Decisions

### Decision 1: Keep Jinja2 Templates or Code Generation?

**Options:**
- A: Delete `.tf.j2` templates, generate everything in Python code
- B: Keep `.tf.j2` templates, pass quilt module config to them

**Recommendation:** Option A - simpler, easier to maintain, no template/code duplication

### Decision 2: Handle create_new_vpc Logic

**The config.json doesn't have create_new_vpc flag.**

**Options:**
- A: Always set `create_new_vpc = false` (use detected VPCs)
- B: Add logic to detect: if `vpc_id == null` then `create_new_vpc = true`

**Recommendation:** Option A for now - detected VPCs are required in config

### Decision 3: Template Storage Pattern

**Current approach: Upload to S3, then reference URLs**

**Keep this pattern because:**
- Quilt module expects `template_file` (local path) for app template
- External IAM needs `iam_template_url` (S3 URL)
- Both templates already in `test/fixtures/stable-*.yaml`

## Implementation Tasks

1. **Fix `_generate_main_tf()` in `deploy/lib/utils.py`**
   - Generate `module "quilt"` block instead of CloudFormation resources
   - Map all config values to quilt module variables
   - Set `iam_template_url` based on pattern

2. **Fix `_generate_variables_tf()` in `deploy/lib/utils.py`**
   - Generate variables that match quilt module inputs
   - Include all required variables: name, template_file, vpc_id, subnets, etc.

3. **Fix `_generate_tfvars_json()` in `deploy/lib/utils.py`**
   - Generate values for all quilt module variables
   - Extract from config.json detected infrastructure

4. **Update `_get_infrastructure_config()` in `deploy/lib/utils.py`**
   - Return config dict with all quilt module variables
   - Not just CloudFormation parameters

5. **Delete obsolete template files**
   - Remove `deploy/templates/external-iam.tf.j2`
   - Remove `deploy/templates/inline-iam.tf.j2`

6. **Update template upload logic in `tf_deploy.py`**
   - Upload `stable-iam.yaml` to `quilt-iam.yaml`
   - Upload `stable-app.yaml` to `quilt-app.yaml`
   - Generate S3 URLs for both

7. **Test with both patterns**
   - Verify `--pattern external-iam` generates correct module config
   - Verify `--pattern inline-iam` generates correct module config (iam_template_url = null)
   - Ensure generated Terraform passes `terraform validate`

## Success Criteria

- [ ] Generated `.deploy/main.tf` contains `module "quilt"` block
- [ ] Module references `../../modules/quilt` as source
- [ ] All quilt module variables are populated from config
- [ ] External IAM pattern sets `iam_template_url` to S3 URL
- [ ] Inline IAM pattern sets `iam_template_url = null`
- [ ] `terraform init` downloads VPC/DB/Search registry modules successfully
- [ ] `terraform validate` passes without errors
- [ ] No direct CloudFormation resource blocks in generated code

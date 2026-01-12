# Architecture Clarification: Quilt-Controlled Templates

**Date**: 2025-11-20  
**Issue**: #91

## Critical Architectural Decision

**WHO OWNS THE TEMPLATES**: Quilt Data

**WHO USES THE INFRASTRUCTURE**: Customers

## The Correct Architecture

### Quilt Responsibilities

1. **Maintains IAM resource definitions** in [config.yaml](config.yaml)
2. **Generates templates** using split script (`/Users/ernest/GitHub/scripts/iam-split/split_iam.py`)
3. **Distributes templates** to customers via:
   - Email attachments
   - Download links
   - Release packages
4. **Maintains Terraform modules** that work with official templates
5. **Versions templates and modules together**

### Customer Responsibilities

1. **Receives templates** from Quilt
2. **Uploads templates** to their own S3 bucket
3. **Sets `var.iam_template_url`** to point to their S3 location
4. **Runs `terraform apply`** using latest module release

## Data Flow

```
Quilt Internal Process:
config.yaml → split_iam.py → quilt-iam.yaml + quilt-app.yaml

Quilt Distribution:
Release → Email/Download → Customer

Customer Deployment:
Download templates → Upload to S3 → terraform apply
```

## Key Implications

- **Module is NOT generic**: Designed specifically for Quilt's template structure
- **config.yaml is source of truth**: Defines which IAM resources exist
- **Version compatibility matters**: Module v1.x works with templates v1.x
- **No customer template customization**: Customers use Quilt's official templates as-is
- **Split script is internal Quilt tool**: Not customer-facing

## What Changed in Specs

### Before (INCORRECT)
- "Customer-provided split templates"
- "Customer runs split script"
- "Module is generic and works with any IAM template"

### After (CORRECT)
- "Quilt-provided split templates"
- "Quilt runs split script as part of release process"
- "Module designed for Quilt's official templates"
- "config.yaml defines expected IAM resources"

## References

- [config.yaml](config.yaml) - Source of truth for IAM resources (24 roles, 8 policies)
- [03-spec-iam-module.md](03-spec-iam-module.md) - Updated to reflect Quilt ownership
- Split script: `/Users/ernest/GitHub/scripts/iam-split/split_iam.py`

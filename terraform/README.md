# Modules to deploy Quilt stacks with Terraform

## Example

```hcl
provider "aws" {
  profile             = ""
  allowed_account_ids = [""]
}

locals {
  name           = ""
  // You receive the build_file CloudFormation Template from your Quilt account
  // manager and check it into git
  build_file     = ""
  quilt_web_host = lookup(module.quilt.stack.parameters, "QuiltWebHost")
}

module "quilt" {
  source = "github.com/quiltdata/iac//terraform/modules/quilt"

  name     = local.name
  internal = false

  template_file = local.build_file

  parameters = {
    AdminEmail               = ""
    CertificateArnELB        = "arn:aws:acm:us-east-1:1234:certificate/abcd"
    QuiltWebHost             = local.quilt_web_host
    PasswordAuth             = ""
    SingleSignOnProvider     = ""
    SingleSignOnClientSecret = ""
    SingleSignOnDomains      = ""
    SingleSignOnClientId     = ""
    SingleSignOnBaseUrl      = ""
  }
}

module "cnames" {
  source = "github.com/quiltdata/iac//terraform/modules/cnames"

  lb_dns_name    = lookup(module.quilt.stack.outputs, "LoadBalancerDNSName")
  quilt_web_host = local.quilt_web_host
  zone_id        = ""
}

output "admin_password" {
  description = "Admin password"
  sensitive   = true
  value       = module.quilt.admin_password
}

output "admin_email" {
  value       = lookup(module.quilt.stack.parameters, "AdminEmail")
  description = "Admin email"
}

output "quilt_web_host" {
  description = "Catalog URL"
  value       = local.quilt_web_host
}
```

## Updating stacks

1. For certain (older) versions of Terraform you must place a new template
at the existing location of `template_url=` and then `terraform apply`.

> Changing `template_url=` on an existing stack may cause Terraform to
> replace the entire stack.

# Terraform basics

## Initialize
* `terraform init`

## Lint and check
* `terraform fmt` lint
* `terraform validate` check syntax

## Plan
* `terraform plan -out tfplan` - dry run

## Apply
If the plan is what you want:
* `terraform apply tfplan`

## Inspect
* `terraform state list`
* `terraform state show 'thing.from.list'`

## Refresh state
* `terraform refresh` - requires an earlier .state file

## Destroy
* `terraform plan -destroy`

## What to check into git
* .tf
* .tfstate files but,
for [security reasons](https://stackoverflow.com/questions/38486335/should-i-commit-tfstate-files-to-git),
these are better handled with
[remote state](https://developer.hashicorp.com/terraform/language/state/remote)
* [.lock.hcl files](https://stackoverflow.com/questions/67963719/should-terraform-lock-hcl-be-included-in-the-gitignore-file)

# References
1. [Hashicorp Terraform Tutorial](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-build)

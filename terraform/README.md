# Modules to deploy Quilt stacks with Terraform

## Example

```hcl
provider "aws" {
  profile             = "YOUR_PROFILE"
  allowed_account_ids = ["YOUR_ACCOUNT"]
}

provider "aws" {
  alias   = "YOUR_ALIAS"
  profile = "ANOTHER_PROFILE"
}

locals {
  name           = "YOUR_STACK_NAME"
  // You receive the build_file from Quilt and check it into git
  build_file     = "../path/to/cf-template/from/quilt.yaml"
  quilt_web_host = lookup(module.quilt.stack.parameters, "QuiltWebHost")
}

module "quilt" {
  source = "github.com/quiltdata/iac//terraform/modules/quilt"

  name     = local.name
  internal = false

  template_file = local.build_file

  parameters = {
    AdminEmail               = "ADMIN_EMAIL"
    CertificateArnELB        = "arn:aws:acm:us-east-1:1234:certificate/abcd"
    QuiltWebHost             = "quilt.YOUR_DOMAIN.com"
    PasswordAuth             = "Disabled"
    SingleSignOnProvider     = ""
    SingleSignOnClientSecret = ""
    SingleSignOnDomains      = ""
    SingleSignOnClientId     = ""
    SingleSignOnBaseUrl      = ""
  }
}

module "cnames" {
  providers = {
    aws = aws.staging
  }
  source = "/Users/akarve/code/iac/terraform/modules/cnames"

  lb_dns_name    = lookup(module.quilt.stack.outputs, "LoadBalancerDNSName")
  quilt_web_host = local.quilt_web_host
  zone_id        = "YOUR_ZONE_ID"
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

> Changing `template_url=` on an existing stack may confuse Terraform into
> replacing the entire stack.

# Terraform primer

## Usage
```sh
export AWS_PROFILE=WHATEVER
```

## Best practices
Be sure to use one of the following properties to prevent
unintentional changes to sensitive accounts:
```
allowed_account_ids = ["foo", "bar"]
forbidden_account_ids = ["baz"]
```

> Idea: one git repo per AWS account, one folder per developer per repo

## Initialize
* `terraform init`

## Lint and check
* `terraform fmt` lint
* `terraform validate` check syntax

## Plan
* `terraform plan -out tfplan` dry run
From the terraform docs:
> Terraform will allow any filename for the plan file,
>but a typical convention is to name it tfplan.

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
1. [VPC convenience class from TF](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)

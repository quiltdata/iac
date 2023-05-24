# What is this repo?
A stub for deploying Quilt stacks via Terraform.

## Updating stacks
1. You must place a new template at the existing location of `template_url=` and
then `terraform apply`. `instance.tf` shows how to sync a local file to S3.

> Changing `template_url=` on an existing stack will confuse Terraform into
> attempting to replace the entire stack because reasons.

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

## What do I check into git
* .tf
* .tfstate files but,
for [security reasons](https://stackoverflow.com/questions/38486335/should-i-commit-tfstate-files-to-git),
these are better handled with
[remote state](https://developer.hashicorp.com/terraform/language/state/remote)
* [.lock.hcl files](https://stackoverflow.com/questions/67963719/should-terraform-lock-hcl-be-included-in-the-gitignore-file)

# References
1. https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-build
1. [VPC convenience class from TF](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)
1. https://github.com/aliatakan/terraform-vpc 


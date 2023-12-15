# Modules to deploy Quilt stacks with Terraform

## Prerequisites
1. You must use a Quilt CloudFormation template that supports an existing database,
existing search domain, and existing vpc in order for the  `quilt` module to
function properly.

1. Rightsize your search cluster with the `quilt`
[`search_*` variables](./modules/quilt/variables.tf).

    The primary consideration is total data node disk size as a function of average
    maximum document size times the total number of deep-indexed documents.
    See [docs on deep indexing](https://docs.quiltdata.com/catalog/searchquery#indexing) for more.

    The following are known good search arguments that you can set on the `quilt` module:

    ```
    # Small
    search_dedicated_master_enabled = false
    search_zone_awareness_enabled = false
    search_instance_count = 1
    search_instance_type = "m5.large.elasticsearch"
    search_volume_size = 512

    # Medium (default)
    search_dedicated_master_enabled = true
    search_zone_awareness_enabled = true
    search_instance_count = 2
    search_instance_type = "m5.xlarge.elasticsearch"
    search_volume_size = 1024

    # Large
    search_dedicated_master_enabled = true
    search_zone_awareness_enabled = true
    search_instance_count = 2
    search_instance_type = "m5.xlarge.elasticsearch"
    search_volume_size = 2*1024
    search_volume_type = "gp3"

    # X-Large
    search_dedicated_master_enabled = true
    search_zone_awareness_enabled = true
    search_instance_count = 2
    search_instance_type = "m5.2xlarge.elasticsearch"
    search_volume_size = 3*1024
    search_volume_type = "gp3"
    search_volume_iops = 16000

    # XX-Large
    search_dedicated_master_enabled = true
    search_zone_awareness_enabled = true
    search_instance_count = 2
    search_instance_type = "m5.4xlarge.elasticsearch"
    search_volume_size = 6*1024
    search_volume_type = "gp3"
    search_volume_iops = 18750

    # XXX-Large
    search_dedicated_master_enabled = true
    search_zone_awareness_enabled = true
    search_instance_count = 2
    search_instance_type = "m5.12xlarge.elasticsearch"
    search_volume_size = 18*1024
    search_volume_type = "gp3"
    search_volume_iops = 40000
    search_volume_throughput = 1187

    # XXXX-Large
    search_dedicated_master_enabled = true
    search_zone_awareness_enabled = true
    search_instance_count = 4
    search_instance_type = "m5.12xlarge.elasticsearch"
    search_volume_size = 18*1024
    search_volume_type = "gp3"
    search_volume_iops = 40000
    search_volume_throughput = 1187
    ```

## Example
See [example.tf](./example.tf).

## Updating stacks
For certain (older) versions of Terraform you must change the contents stored 
at `template_url=` without changing the URL itself.

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

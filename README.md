# Deploy and maintain Quilt stacks with Terraform
## Prerequisites
### [Install Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)

### Get a Terraform-compatible CloudFormation template
You must use a specially configured Terraform-compatible Quilt CloudFormation
template (`local.build_file_path`). Ask your account manger for details.

## Create `main.tf`
See [examples/main.tf](examples/main.tf) for a starting point.

### Provider
The `aws_elasticsearch_domain` called by the `quilt` module requires the
5.20.0 provider version.

### Profile
You may wish to set a specific AWS profile before executing `terraform`
commands. 

```sh
export AWS_PROFILE=your-aws-profile
```
> We discourage the use of `provider.profile` in team environments
> where profile names may differ across users and machines.

### Rightsize your search domain
Your primary consideration is the _total_ data node disk size.
If you multiply your average document size (likely a function of the number of
[deep-indexed](https://docs.quiltdata.com/catalog/searchquery#indexing) documents
and your depth limit) by the total number of documents that will give you "Source data" below.

> Each shallow-indexed document requires a constant number of bytes on the order
> of 1kB.

Follow AWS's documentation on [Sizing Search Domains](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/sizing-domains.html)
and note the following simplified formula:

> `Source data * (1 + number of replicas) * 1.45` = minimum storage requirement

For a production Quilt deployment the number of replicas will be 1, so multiplying
"Source data" by 3 (2.9 rounded up) is a fair starting point. Be sure to account
for growth in your Quilt buckets. "Live" resizing of existing domains is supported
but requires time and may reduce quality of service during the blue/green update.

Below are known-good search sizes that you can set on the `quilt` module.

#### Small
```hcl
search_dedicated_master_enabled = false
search_zone_awareness_enabled = false
search_instance_count = 1
search_instance_type = "m5.large.elasticsearch"
search_volume_size = 512
```

#### Medium (default)
```hcl
search_dedicated_master_enabled = true
search_zone_awareness_enabled = true
search_instance_count = 2
search_instance_type = "m5.xlarge.elasticsearch"
search_volume_size = 1024
```

#### Large
```hcl
search_dedicated_master_enabled = true
search_zone_awareness_enabled = true
search_instance_count = 2
search_instance_type = "m5.xlarge.elasticsearch"
search_volume_size = 2*1024
search_volume_type = "gp3"
```

#### X-Large
```hcl
search_dedicated_master_enabled = true
search_zone_awareness_enabled = true
search_instance_count = 2
search_instance_type = "m5.2xlarge.elasticsearch"
search_volume_size = 3*1024
search_volume_type = "gp3"
search_volume_iops = 16000
```

#### XX-Large
```hcl
search_dedicated_master_enabled = true
search_zone_awareness_enabled = true
search_instance_count = 2
search_instance_type = "m5.4xlarge.elasticsearch"
search_volume_size = 6*1024
search_volume_type = "gp3"
search_volume_iops = 18750
```

#### XXX-Large
```hcl
search_dedicated_master_enabled = true
search_zone_awareness_enabled = true
search_instance_count = 2
search_instance_type = "m5.12xlarge.elasticsearch"
search_volume_size = 18*1024
search_volume_type = "gp3"
search_volume_iops = 40000
search_volume_throughput = 1187
```

#### XXXX-Large
```hcl
search_dedicated_master_enabled = true
search_zone_awareness_enabled = true
search_instance_count = 4
search_instance_type = "m5.12xlarge.elasticsearch"
search_volume_size = 18*1024
search_volume_type = "gp3"
search_volume_iops = 40000
search_volume_throughput = 1187
```

## Deploying and updating Quilt
As a rule, `terraform apply` is sufficient to both deploy and update Quilt.

### Verify the plan
Before calling `apply` read `terraform plan` carefully to ensure that it does
not inadvertently destroy and recreate the stack. The following modifications
are known to cause issues (see [examples/main.tf](examples/main.tf) for context).

1. Modifying `local.name`
1. Modifying `local.build_file_path`
1. Modifying `quilt.template_file`

And for older versions of Terraform and customers whose usage predates the present
module:
1. Modifying `template_url=` in older versions of Terraform and for customers

# Terraform cheat sheet

## Initialize
```sh
terraform init
```

If for instance you change the provider pinning you may need to `-upgrade`:

```sh
terraform init -upgrade
```

## Lint
```
terraform fmt
```

## Validate

```
terraform validate
```

## Plan
```
terraform plan -out tfplan
```

## Apply
If the plan is what you want:
```
terraform apply tfplan
```

## Output sensitive values
Sensitive values must be named in order to display on the command line:
```
terraform output admin_password
```

## State

### Inspect
```
terraform state list
```

Or, to show a specific entity:
```
terraform state show 'thing.from.list'
```

### Refresh
```
terraform refresh
```

## Destroy
```
terraform destroy
```

## Routine updates
1. Update the file at `local.build_file_path` in `main.tf` to the new file you received from Quilt.
    > Do not change the value of `build_file_path` as noted [above](#verify-the-plan).
1. [plan](#plan)
1. [apply](#apply)

## Git version control
### Check these files in
* `*.tf`
* `terraform.lock.hcl`
* Your Quilt `build_file`

### Ignore these files
You may wish to create a `.gitignore` file similar to the following:
```
.terraform
tfplan
```

> We recommend that you use
> [remote state](https://developer.hashicorp.com/terraform/language/state/remote)
> so that no passwords are checked into version control.

# Known issues
## RDS InvalidParameterCombination
> ```
> InvalidParameterCombination: Cannot upgrade postgres from 11.22 to 15.2
> ```

Later versions of the current module set database `auto_minor_version_upgrade = false`.
As a result some users may find their Quilt RDS instance on Postgres 11.19.
These users should _first upgrade to 11.22 using the AWS Console_ and then apply
a recent version of the present module, which will upgrade Postgres to 15.5.

Users who have auto-minor-version-upgraded to 11.22 can apply the present module
directly and ugprade to 15.5.

## Elasticsearch ValidationException
> ```
> Error: updating Elasticsearch Domain (arn:aws:es:foo:bar/baz) config:
> ValidationException: A change/update is in progress. Please wait for it to
> complete before requesting another change.
> ```

If you encounter the above error we suggest that you use the latest version of the
current repo which no longer uses an `auto_tune_options` configuration block in
the `search` module. We further recommend that you only use
[search instances that support Auto-Tune](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/supported-instance-types.html)
as the AWS service may automatically enable Auto-Tune without cause and without warning,
leading to search domains that are difficult to upgrade.

Some users have overcome the above error by pinning the provider to 5.20.0 as shown
below but this is not recommended given that 5.20.0 is an older version.

```hcl
provider "aws" {
    version = "= 5.20.0"
}
```

# References
1. [Terraform: AWS Provider Tutorial](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-build)
1. [Terraform: Basic CLI Features](https://developer.hashicorp.com/terraform/cli/commands)

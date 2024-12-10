provider "aws" {
  allowed_account_ids = [""]
  region              = ""
  default_tags {
    tags = {
      Author  = ""
      Purpose = ""
      Env     = ""
    }
  }
}

terraform {
  backend "s3" {
    bucket = ""
    key    = ""
    region = ""
  }
}

locals {
  name = ""
  // Place a local copy of your CloudFormation YAML Template at build_file_path
  // and check it into git
  build_file_path = ""
  quilt_web_host  = ""
}

module "quilt" {
  // We recommend that you pin the module to the latest tag from the present
  // repository to insulate from future module changes and simplify future `apply`s.
  source = "github.com/quiltdata/iac//modules/quilt?ref=xxxxxxxx"

  name          = local.name
  template_file = local.build_file_path

  internal       = false
  create_new_vpc = true
  cidr           = ""

  // Optional: initialize a new stack from an existing database
  // db_snapshot_identifier = ""

  // Optional: for VPCs that do not support IPV6
  // db_network_type = "IPV4"

  // Optional: deploy Quilt stack to an existing VPC (create_new_vpc = false)
  // vpc_id              = ""
  // api_endpoint        = ""
  // intra_subnets       = ["", ""]
  // private_subnets     = ["", ""]
  // public_subnets      = ["", ""]
  // user_security_group = ""
  // user_subnets        = ["", ""]

  parameters = {
    AdminEmail               = ""
    CertificateArnELB        = ""
    ChunkedChecksums         = "Enabled"
    QuiltWebHost             = local.quilt_web_host
    PasswordAuth             = "Enabled"
    SingleSignOnProvider     = "(Disabled)"
    SingleSignOnClientSecret = ""
    SingleSignOnDomains      = ""
    SingleSignOnClientId     = ""
    SingleSignOnBaseUrl      = ""

    Qurator = "Enabled"
  }
}

module "cnames" {
  source = "github.com/quiltdata/iac//modules/cnames"

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

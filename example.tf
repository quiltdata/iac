provider "aws" {
  profile             = ""
  allowed_account_ids = [""]
}

locals {
  name = ""
  // Place a local copy of your CloudFormation YAML Template at build_file_path
  // and check it into git
  build_file_path = ""
  quilt_web_host  = ""
}

module "quilt" {
  source = "github.com/quiltdata/iac//modules/quilt"

  name          = local.name
  template_file = local.build_file_path

  internal       = false
  create_new_vpc = true
  cidr           = ""
  /* Optional arguments
  // Initialize a new stack from an existing database
  db_snapshot_identifier = ""
  // To run Quilt services in an existing VPC
  vpc_id          = ""
  api_endpoint    = ""
  intra_subnets   = ["", ""]
  private_subnets = ["", ""]
  public_subnets  = ["", ""]
  */

  parameters = {
    AdminEmail               = ""
    CertificateArnELB        = ""
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

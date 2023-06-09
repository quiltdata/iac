provider "aws" {
  region              = "us-east-2"
  allowed_account_ids = ["060758809828"]
}

locals {
  build_file = "/home/dima/src/quilt-deployment/t4/build/dima-dev-tf.yaml"
  bucket     = "cf-templates-2gbmksorj91d-us-east-2"
  key        = "tf/dima-dev-tf.yaml"
}

module "quilt" {
  source = "../../modules/quilt"

  name     = "dima-tf"
  internal = false

  template_url = "https://${local.bucket}.s3.us-east-2.amazonaws.com/${local.key}"
  # template_bucket      = local.bucket
  # template_key         = local.key
  # template_local_file  = local.build_file

  db_multi_az = false

  parameters   = var.parameters
}

output "admin_password" {
  description = "Admin password"
  sensitive   = true
  value       = module.quilt.admin_password
}

output "db_password" {
  description = "DB password"
  sensitive   = true
  value       = module.quilt.db_password
}

output "stack_outputs" {
  description = "CloudFormation outputs"
  value       = module.quilt.stack.outputs
}

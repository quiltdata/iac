locals {
  configuration_error_msg = <<EOH
To run Quilt in an existing VPC set the following attributes:
  1) existing_vpc_id
  2) existing_intra_subnets
  3) existing_private_subnets
  4) existing_public_subnets (if internal == false)
  5) existing_api_endpoint (if internal == true)
Or to create a new VPC, set the above to null.
EOH
}

output "vpc" {
  description = "Internal VPC module. Do not depend on this output."
  value       = module.vpc
}

output "api_endpoint" {
  description = "API Gateway VPC endpoint"
  value = !var.internal ? null : (
    local.new_network_valid ? module.vpc_endpoints.endpoints["api"].id : var.existing_api_endpoint
  )
}

output "created_new_network" {
  value = !local.new_network_valid ? null : "Successfully created new VPC & network."
}

output "configuration_error" {
  value = local.configuration_error ? null : local.configuration_error_msg
  precondition {
    condition     = !local.configuration_error
    error_message = format("%s (existing_network_requires: %v)", local.configuration_error_msg, local.existing_network_requires)
  }
}

output "vpc_id" {
  value = local.new_network_valid ? module.vpc.vpc_id : var.existing_vpc_id
}

output "intra_subnets" {
  value = local.new_network_valid ? module.vpc.intra_subnets : var.existing_intra_subnets
}

output "private_subnets" {
  value = local.new_network_valid ? module.vpc.private_subnets : var.existing_private_subnets
}

output "public_subnets" {
  value = local.new_network_valid ? module.vpc.public_subnets : var.existing_public_subnets
}

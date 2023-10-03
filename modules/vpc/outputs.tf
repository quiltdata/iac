locals {
  configuration_error_msg = <<EOH
To deploy Quilt into an existing VPC set *all* of the following attributes.
(Or to create a new VPC all of the following attributes must be null):
${local.status_str}
EOH
  config_vars = [
    "existing_vpc_id",
    "existing_intra_subnets",
    "existing_private_subnets",
    "existing_public_subnets (if internal == false)",
    "existing_api_endpoint (if internal == true)",
  ]
  status_map = zipmap(
    local.config_vars,
    [for s in local.existing_network_requires : format("%s", s ? "✅" : "❌")],
  )
  status_str = join("\n", [for k, v in local.status_map : format("%s %s", v, k)])
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
    error_message = local.configuration_error_msg
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

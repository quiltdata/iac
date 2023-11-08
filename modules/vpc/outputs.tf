locals {
  var_msg = var.create_new_vpc ? "In order to create a new VPC (create_new_vpc == true)" : (
    "In order to use an existing VPC (create_new_vpc == false)"
  )
  var_map                 = var.create_new_vpc ? local.new_network_requires : local.existing_network_requires
  configuration_error_msg = <<EOH
${local.var_msg} correct the following attributes:
${join("\n", [for k, v in local.var_map : format("%s %s", v ? "✅" : "❌", k)])}
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

output "user_subnets" {
  value = local.new_network_valid ? (
    var.internal ? module.vpc.private_subnets : null
  ) : module.vpc.existing_user_subnets
}

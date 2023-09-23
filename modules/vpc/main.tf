data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_vpc" "existing_vpc" {
  count = var.existing_vpc_id != null  ? 1 : 0
  id    = var.existing_vpc_id
}

locals {
  existing_network_requires = [
    var.existing_vpc_id != null && try(split("/", data.aws_vpc.existing_vpc[0].cidr_block)[1] < 21, false),
    var.existing_intra_subnets != null,
    var.existing_private_subnets != null,
    var.internal ? var.existing_public_subnets == null : var.existing_public_subnets != null,
    var.internal ? var.existing_api_endpoint != null : var.existing_api_endpoint == null,
  ]
  new_network_requires = [
    var.existing_vpc_id == null,
    var.existing_intra_subnets == null,
    var.existing_private_subnets == null,
    var.existing_public_subnets == null,
    var.existing_api_endpoint == null,
  ]
  existing_network_valid = alltrue(local.existing_network_requires)
  new_network_valid      = alltrue(local.new_network_requires)
  configuration_error    = !local.existing_network_valid && !local.new_network_valid

  azs          = slice(data.aws_availability_zones.available.names, 0, 2)
  subnet_cidrs = [for k, v in local.azs : cidrsubnet(var.cidr, 1, k)]
}

module "inner_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  create_vpc = local.new_network_valid

  name = var.name
  cidr = var.cidr

  azs = local.azs
  # 1/2 of address space for each AZ
  # within AZ:
  # 1/2 for private
  # 1/4 for public
  # 1/8 for intra
  # 1/8 spare
  public_subnets               = [for cidr in local.subnet_cidrs : cidrsubnet(cidr, 2, 2)]
  private_subnets              = [for cidr in local.subnet_cidrs : cidrsubnet(cidr, 1, 0)]
  intra_subnets                = [for cidr in local.subnet_cidrs : cidrsubnet(cidr, 3, 6)]
  public_subnet_ipv6_prefixes  = [for k, v in local.azs : k]
  private_subnet_ipv6_prefixes = [for k, v in local.azs : k + 2]
  intra_subnet_ipv6_prefixes   = [for k, v in local.azs : k + 4]

  enable_ipv6                                    = true
  public_subnet_assign_ipv6_address_on_creation  = true
  private_subnet_assign_ipv6_address_on_creation = true
  intra_subnet_assign_ipv6_address_on_creation   = true

  # Disable DNS64. We don't need it, and it breaks IPv4-only services like VPC endpoints.
  public_subnet_enable_dns64  = false
  private_subnet_enable_dns64 = false
  intra_subnet_enable_dns64   = false

  enable_dns_hostnames   = true
  enable_dns_support     = true
  enable_nat_gateway     = true
  one_nat_gateway_per_az = true
}

module "api_gateway_security_group" {
  source = "terraform-aws-modules/security-group/aws"

  create = var.internal && local.new_network_valid

  name        = "${var.name}-api-gateway"
  description = "All inbound HTTPS traffic for the API Gateway Endpoint"
  vpc_id      = module.inner_vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["https-443-tcp"]
}

module "vpc_endpoints" {
  source = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"

  create = local.new_network_valid

  vpc_id             = module.inner_vpc.vpc_id
  security_group_ids = [module.api_gateway_security_group.security_group_id]

  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = concat(module.inner_vpc.public_route_table_ids, module.inner_vpc.private_route_table_ids)
    },
    api = {
      service             = "execute-api"
      private_dns_enabled = true
      subnet_ids          = module.inner_vpc.private_subnets
      create              = var.internal
    },
  }
}

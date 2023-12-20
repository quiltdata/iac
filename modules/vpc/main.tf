data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_vpc" "existing_vpc" {
  count = var.existing_vpc_id != null ? 1 : 0
  id    = var.existing_vpc_id
}

locals {
  existing_network_requires = {
    "create_new_vpc == false" : var.create_new_vpc == false,
    "vpc_id (required)" : var.existing_vpc_id != null,
    "intra_subnets (required)" : var.existing_intra_subnets != null,
    "private_subnets (required)" : var.existing_private_subnets != null,
    "public_subnets (required if var.internal == false, else must be null)" : var.internal == (var.existing_public_subnets == null),
    "user_security_group (required)" : var.existing_user_security_group != null,
    "user_subnets (required if var.internal == true, else must be null)" : var.internal == (var.existing_user_subnets != null)
    "api_endpoint (required if var.internal == true, else must be null)" : var.internal == (var.existing_api_endpoint != null),
  }
  new_network_requires = {
    "create_new_vpc == true" : var.create_new_vpc == true,
    "vpc_id == null" : var.existing_vpc_id == null,
    "intra_subnets == null" : var.existing_intra_subnets == null,
    "private_subnets == null" : var.existing_private_subnets == null,
    "public_subnets == null" : var.existing_public_subnets == null,
    "user_security_group == null" : var.existing_user_security_group == null,
    "user_subnets == null" : var.existing_user_subnets == null,
    "api_endpoint == null" : var.existing_api_endpoint == null,
  }
  existing_network_valid = alltrue(values(local.existing_network_requires))
  new_network_valid      = alltrue(values(local.new_network_requires))
  configuration_error    = !local.existing_network_valid && !local.new_network_valid

  azs          = slice(data.aws_availability_zones.available.names, 0, 2)
  subnet_cidrs = [for k, v in local.azs : cidrsubnet(var.cidr, 1, k)]
}

module "vpc" {
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

// Module name no longer accurate (see description); changing name causes tf apply to fail
module "api_gateway_security_group" {
  source = "terraform-aws-modules/security-group/aws"

  create = local.new_network_valid

  name        = "${var.name}-user-ingress"
  description = "User ingress security group for API Gateway Endpoint, Quilt load balancer"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["https-443-tcp", "http-80-tcp"]
}

module "vpc_endpoints" {
  source = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"

  create = local.new_network_valid

  vpc_id             = module.vpc.vpc_id
  security_group_ids = [module.api_gateway_security_group.security_group_id]

  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = concat(module.vpc.public_route_table_ids, module.vpc.private_route_table_ids)
    },
    api = {
      service             = "execute-api"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      create              = var.internal
    },
  }
}

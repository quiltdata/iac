data "aws_availability_zones" "available" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
  subnet_cidrs = [for k, v in local.azs : cidrsubnet(var.cidr, 1, k)]
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.name
  cidr = var.cidr

  azs = local.azs
  # 1/2 of address space for each AZ
  # within AZ:
  # 1/2 for private
  # 1/4 for public
  # 1/8 for intra
  # 1/8 spare
  public_subnets  = [for cidr in local.subnet_cidrs : cidrsubnet(cidr, 2, 2)]
  private_subnets = [for cidr in local.subnet_cidrs : cidrsubnet(cidr, 1, 0)]
  intra_subnets   = [for cidr in local.subnet_cidrs : cidrsubnet(cidr, 3, 6)]

  enable_dns_hostnames   = true
  enable_dns_support     = true
  enable_nat_gateway     = true
  one_nat_gateway_per_az = true
}

module "api_gateway_security_group" {
  source = "terraform-aws-modules/security-group/aws"

  create = var.internal

  name = "${var.name}-api-gateway"
  description = "All inbound HTTPS traffic for the API Gateway Endpoint"
  vpc_id = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["https-443-tcp"]
}

module "vpc_endpoints" {
  source = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"

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

module "vpc" {
  source = "../vpc"

  name     = var.name
  cidr     = var.cidr
  internal = var.internal
}

module "db" {
  source = "../db"

  identifier = var.name
  vpc_id = module.vpc.vpc.vpc_id
  subnet_ids = module.vpc.vpc.intra_subnets
  instance_class = var.db_instance_class
  snapshot_identifier = var.db_snapshot_identifier
}

resource "random_password" "admin_password" {
  length = 16
}

resource "aws_cloudformation_stack" "stack" {
  name         = var.name
  template_url = var.template_url
  capabilities = ["CAPABILITY_NAMED_IAM"]

  parameters = merge(
    var.parameters,
    {
      VPC           = module.vpc.vpc.vpc_id
      IntraSubnets  = join(",", module.vpc.vpc.intra_subnets)
      Subnets       = join(",", module.vpc.vpc.private_subnets)
      PublicSubnets = var.internal ? null : join(",", module.vpc.vpc.public_subnets)

      ApiGatewayVPCEndpoint = var.internal ? module.vpc.api_endpoint.id : null

      DBUser     = module.db.db.db_instance_username
      DBPassword = module.db.db.db_instance_password
      DBEndpoint = module.db.db.db_instance_endpoint
      DBName     = module.db.db.db_instance_name

      DBAccessorSecurityGroup = module.db.db_accessor_security_group.security_group_id

      AdminPassword = random_password.admin_password.result
    }
  )
}

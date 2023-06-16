locals {
  template_key = "quilt.yaml"
  template_url = "https://${aws_s3_bucket.cft_bucket.bucket_regional_domain_name}/${local.template_key}"
}

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
  multi_az = var.db_multi_az
}

resource "random_password" "admin_password" {
  length = 16
}

resource "aws_s3_bucket" "cft_bucket" {
  bucket_prefix = "quilt-templates-${var.name}-"

  # Nothing valuable in this bucket, so make the cleanup easier.
  force_destroy = true
}

resource "aws_s3_object" "cft" {
  bucket = aws_s3_bucket.cft_bucket.id
  key    = local.template_key
  source = var.template_file
  etag   = filemd5(var.template_file)
}

resource "aws_cloudformation_stack" "stack" {
  name         = var.name
  template_url = local.template_url
  depends_on   = [aws_s3_object.cft]
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

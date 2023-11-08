terraform {
  required_version = ">= 1.5.0"
}

locals {
  template_key = "quilt.yaml"
  template_url = "https://${aws_s3_bucket.cft_bucket.bucket_regional_domain_name}/${local.template_key}"
}

module "vpc" {
  source = "../vpc"

  name     = var.name
  cidr     = var.cidr
  internal = var.internal

  create_new_vpc               = var.create_new_vpc
  existing_api_endpoint        = var.api_endpoint
  existing_vpc_id              = var.vpc_id
  existing_intra_subnets       = var.intra_subnets
  existing_private_subnets     = var.private_subnets
  existing_public_subnets      = var.public_subnets
  existing_user_security_group = var.user_security_group
  existing_user_subnets        = var.user_subnets
}

module "db" {
  source = "../db"

  identifier = var.name

  snapshot_identifier = var.db_snapshot_identifier

  network_type = var.db_network_type
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.intra_subnets

  instance_class = var.db_instance_class
  multi_az       = var.db_multi_az
}

module "search" {
  source = "../search"

  domain_name = var.name

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.intra_subnets

  auto_tune_desired_state  = var.search_auto_tune_desired_state
  instance_count           = var.search_instance_count
  instance_type            = var.search_instance_type
  dedicated_master_enabled = var.search_dedicated_master_enabled
  dedicated_master_count   = var.search_dedicated_master_count
  dedicated_master_type    = var.search_dedicated_master_type
  zone_awareness_enabled   = var.search_zone_awareness_enabled
  volume_size              = var.search_volume_size
  volume_type              = var.search_volume_type
}

resource "random_password" "admin_password" {
  length = 16
}

resource "aws_s3_bucket" "cft_bucket" {
  bucket_prefix = "quilt-templates-${var.name}-"

  # Nothing valuable in this bucket, so make the cleanup easier.
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "cft_bucket_versioning" {
  bucket = aws_s3_bucket.cft_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
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
      VPC           = module.vpc.vpc_id
      Subnets       = join(",", module.vpc.private_subnets)
      PublicSubnets = var.internal ? null : join(",", module.vpc.public_subnets)
      UserSubnets   = module.vpc.user_subnets
      UserSecurityGroup = module.vpc.ingress_security_group

      ApiGatewayVPCEndpoint = module.vpc.api_endpoint

      DBUrl = format("postgresql://%s:%s@%s/%s",
        module.db.db.db_instance_username,
        module.db.db.db_instance_password,
        module.db.db.db_instance_endpoint,
        module.db.db.db_instance_name,
      )

      DBAccessorSecurityGroup = module.db.db_accessor_security_group.security_group_id

      SearchDomainEndpoint = module.search.search.endpoint
      SearchDomainArn      = module.search.search.arn

      SearchClusterAccessorSecurityGroup = module.search.search_accessor_security_group.security_group_id

      AdminPassword = random_password.admin_password.result
    }
  )
}

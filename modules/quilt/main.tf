terraform {
  required_version = ">= 1.5.0"
}

locals {
  template_key = "quilt.yaml"
  template_url = "https://${aws_s3_bucket.cft_bucket.bucket_regional_domain_name}/${local.template_key}"

  # Determine IAM stack name for data source query
  iam_stack_name = var.iam_stack_name != null ? var.iam_stack_name : "${var.name}-iam"

  # Transform IAM module outputs to CloudFormation parameters
  # Remove "Arn" suffix from output names to match parameter names
  # Only populate when external IAM pattern is active (var.iam_template_url != null)
  iam_parameters = var.iam_template_url != null ? {
    # IAM Role parameters (24 roles)
    SearchHandlerRole                = try(data.aws_cloudformation_stack.iam[0].outputs["SearchHandlerRoleArn"], null)
    EsIngestRole                     = try(data.aws_cloudformation_stack.iam[0].outputs["EsIngestRoleArn"], null)
    ManifestIndexerRole              = try(data.aws_cloudformation_stack.iam[0].outputs["ManifestIndexerRoleArn"], null)
    AccessCountsRole                 = try(data.aws_cloudformation_stack.iam[0].outputs["AccessCountsRoleArn"], null)
    PkgEventsRole                    = try(data.aws_cloudformation_stack.iam[0].outputs["PkgEventsRoleArn"], null)
    DuckDBSelectLambdaRole           = try(data.aws_cloudformation_stack.iam[0].outputs["DuckDBSelectLambdaRoleArn"], null)
    PkgPushRole                      = try(data.aws_cloudformation_stack.iam[0].outputs["PkgPushRoleArn"], null)
    PackagerRole                     = try(data.aws_cloudformation_stack.iam[0].outputs["PackagerRoleArn"], null)
    AmazonECSTaskExecutionRole       = try(data.aws_cloudformation_stack.iam[0].outputs["AmazonECSTaskExecutionRoleArn"], null)
    ManagedUserRole                  = try(data.aws_cloudformation_stack.iam[0].outputs["ManagedUserRoleArn"], null)
    MigrationLambdaRole              = try(data.aws_cloudformation_stack.iam[0].outputs["MigrationLambdaRoleArn"], null)
    TrackingCronRole                 = try(data.aws_cloudformation_stack.iam[0].outputs["TrackingCronRoleArn"], null)
    ApiRole                          = try(data.aws_cloudformation_stack.iam[0].outputs["ApiRoleArn"], null)
    TimestampResourceHandlerRole     = try(data.aws_cloudformation_stack.iam[0].outputs["TimestampResourceHandlerRoleArn"], null)
    TabulatorRole                    = try(data.aws_cloudformation_stack.iam[0].outputs["TabulatorRoleArn"], null)
    TabulatorOpenQueryRole           = try(data.aws_cloudformation_stack.iam[0].outputs["TabulatorOpenQueryRoleArn"], null)
    IcebergLambdaRole                = try(data.aws_cloudformation_stack.iam[0].outputs["IcebergLambdaRoleArn"], null)
    T4BucketReadRole                 = try(data.aws_cloudformation_stack.iam[0].outputs["T4BucketReadRoleArn"], null)
    T4BucketWriteRole                = try(data.aws_cloudformation_stack.iam[0].outputs["T4BucketWriteRoleArn"], null)
    S3ProxyRole                      = try(data.aws_cloudformation_stack.iam[0].outputs["S3ProxyRoleArn"], null)
    S3LambdaRole                     = try(data.aws_cloudformation_stack.iam[0].outputs["S3LambdaRoleArn"], null)
    S3SNSToEventBridgeRole           = try(data.aws_cloudformation_stack.iam[0].outputs["S3SNSToEventBridgeRoleArn"], null)
    S3HashLambdaRole                 = try(data.aws_cloudformation_stack.iam[0].outputs["S3HashLambdaRoleArn"], null)
    S3CopyLambdaRole                 = try(data.aws_cloudformation_stack.iam[0].outputs["S3CopyLambdaRoleArn"], null)

    # IAM Policy parameters (8 policies)
    BucketReadPolicy                 = try(data.aws_cloudformation_stack.iam[0].outputs["BucketReadPolicyArn"], null)
    BucketWritePolicy                = try(data.aws_cloudformation_stack.iam[0].outputs["BucketWritePolicyArn"], null)
    RegistryAssumeRolePolicy         = try(data.aws_cloudformation_stack.iam[0].outputs["RegistryAssumeRolePolicyArn"], null)
    ManagedUserRoleBasePolicy        = try(data.aws_cloudformation_stack.iam[0].outputs["ManagedUserRoleBasePolicyArn"], null)
    UserAthenaNonManagedRolePolicy   = try(data.aws_cloudformation_stack.iam[0].outputs["UserAthenaNonManagedRolePolicyArn"], null)
    UserAthenaManagedRolePolicy      = try(data.aws_cloudformation_stack.iam[0].outputs["UserAthenaManagedRolePolicyArn"], null)
    TabulatorOpenQueryPolicy         = try(data.aws_cloudformation_stack.iam[0].outputs["TabulatorOpenQueryPolicyArn"], null)
    T4DefaultBucketReadPolicy        = try(data.aws_cloudformation_stack.iam[0].outputs["T4DefaultBucketReadPolicyArn"], null)
  } : {}
}

# Data source to query IAM stack outputs (only when external IAM pattern active)
data "aws_cloudformation_stack" "iam" {
  count = var.iam_template_url != null ? 1 : 0
  name  = local.iam_stack_name
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

  instance_class      = var.db_instance_class
  multi_az            = var.db_multi_az
  deletion_protection = var.db_deletion_protection
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
  volume_iops              = var.search_volume_iops
  volume_throughput        = var.search_volume_throughput
}

# Conditionally instantiate IAM module when external IAM pattern is active
module "iam" {
  count  = var.iam_template_url != null ? 1 : 0
  source = "../iam"

  name         = var.name
  template_url = var.iam_template_url

  iam_stack_name = var.iam_stack_name
  parameters     = var.iam_parameters
  tags           = merge(var.iam_tags, { ManagedBy = "Terraform" })
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
  depends_on = [
    aws_s3_object.cft,
    /* Prevent races between module.vpc and module.quilt resources. For example:
     * If ECS tries to reach ECR before private subnet NAT is available then ECS fails. */
    module.vpc,
    /* Ensure IAM module completes before application stack deployment when external IAM pattern is used */
    module.iam,
  ]
  capabilities      = ["CAPABILITY_NAMED_IAM"]
  notification_arns = var.stack_notification_arns

  parameters = merge(
    var.parameters,
    local.iam_parameters, # IAM ARNs from external stack (or empty map if inline IAM)
    {
      VPC               = module.vpc.vpc_id
      Subnets           = join(",", module.vpc.private_subnets)
      PublicSubnets     = var.internal ? null : join(",", module.vpc.public_subnets)
      UserSubnets       = module.vpc.user_subnets == null ? null : join(",", module.vpc.user_subnets)
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

  timeouts {
    delete = var.delete_timeout
    update = var.update_timeout
    create = var.create_timeout
  }

  on_failure = var.on_failure

  lifecycle {
    ignore_changes = [
      on_failure,
    ]
  }
}

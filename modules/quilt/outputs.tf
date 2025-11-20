output "vpc" {
  description = "VPC"
  value       = module.vpc.vpc
}

output "admin_password" {
  description = "Admin password"
  sensitive   = true
  value       = random_password.admin_password.result
}

output "db_password" {
  description = "DB password"
  sensitive   = true
  value       = module.db.db.db_instance_password
}

output "stack" {
  description = "CloudFormation outputs"
  value       = aws_cloudformation_stack.stack
}

# New Conditional Outputs for External IAM Pattern

output "iam_stack_id" {
  description = "CloudFormation IAM stack ID (null if inline IAM pattern)"
  value       = var.iam_template_url != null ? module.iam[0].stack_id : null
}

output "iam_stack_name" {
  description = "CloudFormation IAM stack name (null if inline IAM pattern)"
  value       = var.iam_template_url != null ? module.iam[0].stack_name : null
}

output "iam_role_arns" {
  description = "Map of IAM role names to ARNs (empty if inline IAM pattern)"
  value = var.iam_template_url != null ? {
    SearchHandlerRole            = module.iam[0].SearchHandlerRoleArn
    EsIngestRole                 = module.iam[0].EsIngestRoleArn
    ManifestIndexerRole          = module.iam[0].ManifestIndexerRoleArn
    AccessCountsRole             = module.iam[0].AccessCountsRoleArn
    PkgEventsRole                = module.iam[0].PkgEventsRoleArn
    DuckDBSelectLambdaRole       = module.iam[0].DuckDBSelectLambdaRoleArn
    PkgPushRole                  = module.iam[0].PkgPushRoleArn
    PackagerRole                 = module.iam[0].PackagerRoleArn
    AmazonECSTaskExecutionRole   = module.iam[0].AmazonECSTaskExecutionRoleArn
    ManagedUserRole              = module.iam[0].ManagedUserRoleArn
    MigrationLambdaRole          = module.iam[0].MigrationLambdaRoleArn
    TrackingCronRole             = module.iam[0].TrackingCronRoleArn
    ApiRole                      = module.iam[0].ApiRoleArn
    TimestampResourceHandlerRole = module.iam[0].TimestampResourceHandlerRoleArn
    TabulatorRole                = module.iam[0].TabulatorRoleArn
    TabulatorOpenQueryRole       = module.iam[0].TabulatorOpenQueryRoleArn
    IcebergLambdaRole            = module.iam[0].IcebergLambdaRoleArn
    T4BucketReadRole             = module.iam[0].T4BucketReadRoleArn
    T4BucketWriteRole            = module.iam[0].T4BucketWriteRoleArn
    S3ProxyRole                  = module.iam[0].S3ProxyRoleArn
    S3LambdaRole                 = module.iam[0].S3LambdaRoleArn
    S3SNSToEventBridgeRole       = module.iam[0].S3SNSToEventBridgeRoleArn
    S3HashLambdaRole             = module.iam[0].S3HashLambdaRoleArn
    S3CopyLambdaRole             = module.iam[0].S3CopyLambdaRoleArn
  } : {}
}

output "iam_policy_arns" {
  description = "Map of IAM policy names to ARNs (empty if inline IAM pattern)"
  value = var.iam_template_url != null ? {
    BucketReadPolicy               = module.iam[0].BucketReadPolicyArn
    BucketWritePolicy              = module.iam[0].BucketWritePolicyArn
    RegistryAssumeRolePolicy       = module.iam[0].RegistryAssumeRolePolicyArn
    ManagedUserRoleBasePolicy      = module.iam[0].ManagedUserRoleBasePolicyArn
    UserAthenaNonManagedRolePolicy = module.iam[0].UserAthenaNonManagedRolePolicyArn
    UserAthenaManagedRolePolicy    = module.iam[0].UserAthenaManagedRolePolicyArn
    TabulatorOpenQueryPolicy       = module.iam[0].TabulatorOpenQueryPolicyArn
    T4DefaultBucketReadPolicy      = module.iam[0].T4DefaultBucketReadPolicyArn
  } : {}
}

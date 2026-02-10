# Stack Metadata Outputs

output "stack_id" {
  description = "CloudFormation IAM stack ID"
  value       = aws_cloudformation_stack.iam.id
}

output "stack_name" {
  description = "CloudFormation IAM stack name (for reference by other stacks)"
  value       = aws_cloudformation_stack.iam.name
}

# IAM Role ARN Outputs (24 roles from config.yaml)
# These outputs extract ARNs from CloudFormation stack outputs

output "SearchHandlerRoleArn" {
  description = "ARN of SearchHandlerRole"
  value       = aws_cloudformation_stack.iam.outputs["SearchHandlerRoleArn"]
}

output "EsIngestRoleArn" {
  description = "ARN of EsIngestRole"
  value       = aws_cloudformation_stack.iam.outputs["EsIngestRoleArn"]
}

output "ManifestIndexerRoleArn" {
  description = "ARN of ManifestIndexerRole"
  value       = aws_cloudformation_stack.iam.outputs["ManifestIndexerRoleArn"]
}

output "AccessCountsRoleArn" {
  description = "ARN of AccessCountsRole"
  value       = aws_cloudformation_stack.iam.outputs["AccessCountsRoleArn"]
}

output "PkgEventsRoleArn" {
  description = "ARN of PkgEventsRole"
  value       = aws_cloudformation_stack.iam.outputs["PkgEventsRoleArn"]
}

output "DuckDBSelectLambdaRoleArn" {
  description = "ARN of DuckDBSelectLambdaRole"
  value       = aws_cloudformation_stack.iam.outputs["DuckDBSelectLambdaRoleArn"]
}

output "PkgPushRoleArn" {
  description = "ARN of PkgPushRole"
  value       = aws_cloudformation_stack.iam.outputs["PkgPushRoleArn"]
}

output "PackagerRoleArn" {
  description = "ARN of PackagerRole"
  value       = aws_cloudformation_stack.iam.outputs["PackagerRoleArn"]
}

output "AmazonECSTaskExecutionRoleArn" {
  description = "ARN of AmazonECSTaskExecutionRole"
  value       = aws_cloudformation_stack.iam.outputs["AmazonECSTaskExecutionRoleArn"]
}

output "ManagedUserRoleArn" {
  description = "ARN of ManagedUserRole"
  value       = aws_cloudformation_stack.iam.outputs["ManagedUserRoleArn"]
}

output "MigrationLambdaRoleArn" {
  description = "ARN of MigrationLambdaRole"
  value       = aws_cloudformation_stack.iam.outputs["MigrationLambdaRoleArn"]
}

output "TrackingCronRoleArn" {
  description = "ARN of TrackingCronRole"
  value       = aws_cloudformation_stack.iam.outputs["TrackingCronRoleArn"]
}

output "ApiRoleArn" {
  description = "ARN of ApiRole"
  value       = aws_cloudformation_stack.iam.outputs["ApiRoleArn"]
}

output "TimestampResourceHandlerRoleArn" {
  description = "ARN of TimestampResourceHandlerRole"
  value       = aws_cloudformation_stack.iam.outputs["TimestampResourceHandlerRoleArn"]
}

output "TabulatorRoleArn" {
  description = "ARN of TabulatorRole"
  value       = aws_cloudformation_stack.iam.outputs["TabulatorRoleArn"]
}

output "TabulatorOpenQueryRoleArn" {
  description = "ARN of TabulatorOpenQueryRole"
  value       = aws_cloudformation_stack.iam.outputs["TabulatorOpenQueryRoleArn"]
}

output "IcebergLambdaRoleArn" {
  description = "ARN of IcebergLambdaRole"
  value       = aws_cloudformation_stack.iam.outputs["IcebergLambdaRoleArn"]
}

output "T4BucketReadRoleArn" {
  description = "ARN of T4BucketReadRole"
  value       = aws_cloudformation_stack.iam.outputs["T4BucketReadRoleArn"]
}

output "T4BucketWriteRoleArn" {
  description = "ARN of T4BucketWriteRole"
  value       = aws_cloudformation_stack.iam.outputs["T4BucketWriteRoleArn"]
}

output "S3ProxyRoleArn" {
  description = "ARN of S3ProxyRole"
  value       = aws_cloudformation_stack.iam.outputs["S3ProxyRoleArn"]
}

output "S3LambdaRoleArn" {
  description = "ARN of S3LambdaRole"
  value       = aws_cloudformation_stack.iam.outputs["S3LambdaRoleArn"]
}

output "S3SNSToEventBridgeRoleArn" {
  description = "ARN of S3SNSToEventBridgeRole"
  value       = aws_cloudformation_stack.iam.outputs["S3SNSToEventBridgeRoleArn"]
}

output "S3HashLambdaRoleArn" {
  description = "ARN of S3HashLambdaRole"
  value       = aws_cloudformation_stack.iam.outputs["S3HashLambdaRoleArn"]
}

output "S3CopyLambdaRoleArn" {
  description = "ARN of S3CopyLambdaRole"
  value       = aws_cloudformation_stack.iam.outputs["S3CopyLambdaRoleArn"]
}

# IAM Policy ARN Outputs (8 policies from config.yaml)

output "BucketReadPolicyArn" {
  description = "ARN of BucketReadPolicy"
  value       = aws_cloudformation_stack.iam.outputs["BucketReadPolicyArn"]
}

output "BucketWritePolicyArn" {
  description = "ARN of BucketWritePolicy"
  value       = aws_cloudformation_stack.iam.outputs["BucketWritePolicyArn"]
}

output "RegistryAssumeRolePolicyArn" {
  description = "ARN of RegistryAssumeRolePolicy"
  value       = aws_cloudformation_stack.iam.outputs["RegistryAssumeRolePolicyArn"]
}

output "ManagedUserRoleBasePolicyArn" {
  description = "ARN of ManagedUserRoleBasePolicy"
  value       = aws_cloudformation_stack.iam.outputs["ManagedUserRoleBasePolicyArn"]
}

output "UserAthenaNonManagedRolePolicyArn" {
  description = "ARN of UserAthenaNonManagedRolePolicy"
  value       = aws_cloudformation_stack.iam.outputs["UserAthenaNonManagedRolePolicyArn"]
}

output "UserAthenaManagedRolePolicyArn" {
  description = "ARN of UserAthenaManagedRolePolicy"
  value       = aws_cloudformation_stack.iam.outputs["UserAthenaManagedRolePolicyArn"]
}

output "TabulatorOpenQueryPolicyArn" {
  description = "ARN of TabulatorOpenQueryPolicy"
  value       = aws_cloudformation_stack.iam.outputs["TabulatorOpenQueryPolicyArn"]
}

output "T4DefaultBucketReadPolicyArn" {
  description = "ARN of T4DefaultBucketReadPolicy"
  value       = aws_cloudformation_stack.iam.outputs["T4DefaultBucketReadPolicyArn"]
}

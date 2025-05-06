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

output "common_tags" {
  description = "Common tags applied to resources"
  value       = local.common_tags
}

output "stack_dependent_tags" {
  description = "Tags that include the stack ID"
  value       = local.stack_dependent_tags
}

output "stack_id" {
  description = "CloudFormation stack ID"
  value       = aws_cloudformation_stack.stack.id
}

locals {
  # Common tags to be applied to all resources
  common_tags = {
    "quilt:stack-name" = var.name
    # Stack ID will be added after stack creation for resources that depend on the stack
  }

  # Tags that include the stack ID, for resources created after the CloudFormation stack
  stack_dependent_tags = {
    "quilt:stack-name" = var.name
    "quilt:stack-id"   = aws_cloudformation_stack.stack.id
  }
}

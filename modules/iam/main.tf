terraform {
  required_version = ">= 1.5.0"
}

locals {
  # Use provided IAM stack name or default to {name}-iam
  iam_stack_name = var.iam_stack_name != null ? var.iam_stack_name : "${var.name}-iam"
}

resource "aws_cloudformation_stack" "iam" {
  name         = local.iam_stack_name
  template_url = var.template_url

  parameters = var.parameters

  capabilities = var.capabilities

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

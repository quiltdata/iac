variable "parameters" {
  type        = map(any)
  nullable    = false
  description = "CFT parameters"
}

variable "stack_name" {
  type     = string
  nullable = false
}

variable "template_url" {
  type     = string
  nullable = false
}

variable "user_tags" {
  type        = map(any)
  description = "User-provided resource tags"
  default     = {}
}

resource "aws_cloudformation_stack" "stack" {
  name         = var.stack_name
  template_url = var.template_url
  capabilities = ["CAPABILITY_NAMED_IAM"]
  # TODO iam_role_arn = for service role
  parameters = var.parameters
  tags = merge(
    var.user_tags,
    {
      Source = "Terraform"
      Repo   = "quiltdata/tf-quilt-stacks"
    },
  )
}

output "alb_dns_name" { value = aws_cloudformation_stack.stack.outputs.LoadBalancerDNSName }
output "stack_name" { value = var.stack_name }


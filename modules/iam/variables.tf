# Required Variables

variable "name" {
  type        = string
  nullable    = false
  description = "Base name for the IAM stack. Default stack name will be: {name}-iam"
  validation {
    condition     = length(var.name) <= 20 && can(regex("^[a-z0-9-]+$", var.name))
    error_message = "Lowercase alphanumerics and hyphens; no longer than 20 characters."
  }
}

variable "template_url" {
  type        = string
  nullable    = false
  description = "S3 HTTPS URL of the Quilt IAM CloudFormation template"
  validation {
    condition     = can(regex("^https://[a-z0-9.-]+\\.s3[.-][a-z0-9.-]*\\.amazonaws\\.com/.+\\.(yaml|yml|json)$", var.template_url))
    error_message = "Must be a valid S3 HTTPS URL pointing to a YAML or JSON CloudFormation template."
  }
}

# Optional Variables

variable "iam_stack_name" {
  type        = string
  nullable    = true
  default     = null
  description = "Override IAM stack name. If not provided, defaults to: {name}-iam"
  validation {
    condition     = var.iam_stack_name == null || (length(var.iam_stack_name) <= 128 && can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.iam_stack_name)))
    error_message = "Stack name must start with a letter and contain only alphanumeric characters and hyphens. Max length: 128 characters."
  }
}

variable "parameters" {
  type        = map(string)
  nullable    = false
  default     = {}
  description = "CloudFormation parameters to pass to the IAM stack for customization"
}

variable "tags" {
  type        = map(string)
  nullable    = false
  default     = {}
  description = "Tags to apply to the IAM CloudFormation stack"
}

variable "capabilities" {
  type        = list(string)
  nullable    = false
  default     = ["CAPABILITY_NAMED_IAM"]
  description = "CloudFormation capabilities required for IAM resource creation"
}

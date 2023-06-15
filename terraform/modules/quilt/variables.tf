variable "name" {
  type        = string
  nullable    = false
  description = "Name to use for the VPC, DB, and CloudFormation stack, as well as a prefix for other resources"
}

variable "cidr" {
  type        = string
  nullable    = false
  default     = "10.0.0.0/16"
  description = "CIDR block for the VPC"
}

variable "internal" {
  type        = bool
  nullable    = false
  description = "Whether CloudFormation template uses internet-facing or internal ELBs"
}

variable "db_snapshot_identifier" {
  type        = string
  nullable    = true
  default     = null
  description = "If set, restore the DB from the given snapshot"
}

variable "db_instance_class" {
  type        = string
  nullable    = false
  default     = "db.t3.small"
  description = "EC2 instance class to use for the DB"
}

variable "db_multi_az" {
  type        = bool
  nullable    = true
  default     = true
  description = "Whether to enable Multi-AZ for the DB"
}

variable "template_url" {
  type        = string
  nullable    = false
  description = "S3 URL of the CloudFormation template"
}

variable "template_local_file" {
  type        = string
  nullable    = true
  default     = null
  description = "(Dev-only) local file to upload to S3 to use as the CloudFormation template"
}

variable "template_bucket" {
  type        = string
  nullable    = true
  default     = null
  description = "(Dev-only) S3 bucket to use for the template upload; must match template_url"
}

variable "template_key" {
  type     = string
  nullable = true
  default  = null
  description = "(Dev-only) S3 key to use for the template upload; must match template_url"
}

variable "parameters" {
  type        = map(any)
  nullable    = false
  description = "Parameters to pass to the CloudFormation stack"
}

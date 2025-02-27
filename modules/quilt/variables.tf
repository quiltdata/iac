# defaults match internal deployment repo as of commit 99d1f06ad11c7a0ad48e5402f32506b20e3f30a8

variable "name" {
  type        = string
  nullable    = false
  description = "Name to use for the VPC, DB, and CloudFormation stack, as well as a prefix for other resources"
  validation {
    condition     = length(var.name) <= 20 && can(regex("^[a-z0-9-]+$", var.name))
    error_message = "Lowercase alphanumerics and hyphens; no longer than 20 characters."
  }
}

variable "create_new_vpc" {
  type        = bool
  default     = false
  description = "Create a new VPC if true, otherwise use an existing VPC."
}

variable "cidr" {
  type        = string
  nullable    = false
  default     = "10.0.0.0/16"
  description = "CIDR block for the VPC. Set for validation even if create_new_vpc == false."
}

variable "internal" {
  type        = bool
  nullable    = false
  description = "If true create an inward ELBv2, else create an internet-facing ELBv2."
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

variable "db_network_type" {
  type        = string
  default     = "DUAL"
  description = "'IPV4' (required for IPV4-only VPCs) or 'DUAL'"
}

variable "db_deletion_protection" {
  type        = bool
  nullable    = false
  default     = true
  description = "Set to true for production environments to prevent accidental deletion of stack database."
}

variable "search_auto_tune_desired_state" {
  type        = string
  nullable    = false
  default     = "DISABLED"
  description = "The Auto-Tune desired state for the ElasticSearch domain"
}

variable "search_instance_count" {
  type        = number
  nullable    = false
  default     = 2
  description = "Number of data instances in the ElasticSearch cluster"
}

variable "search_instance_type" {
  type        = string
  nullable    = false
  default     = "m5.xlarge.elasticsearch"
  description = "Instance type of data nodes in the ElasticSearch cluster"
}

variable "search_dedicated_master_enabled" {
  type        = bool
  nullable    = false
  default     = true
  description = "Whether dedicated master nodes are enabled for the ElasticSearch cluster"
}

variable "search_dedicated_master_count" {
  type        = number
  nullable    = false
  default     = 3
  description = "Number of master nodes in the ElasticSearch cluster"
}

variable "search_dedicated_master_type" {
  type        = string
  nullable    = false
  default     = "m5.large.elasticsearch"
  description = "Instance type of the dedicated master nodes in the ElasticSearch cluster"
}

variable "search_zone_awareness_enabled" {
  type        = bool
  nullable    = false
  default     = true
  description = "Whether to enable Multi-AZ for the ElasticSearch cluster"
}

variable "search_volume_iops" {
  type        = number
  default     = null
  description = "EBS IOPS (required for gp3 volumes)"
}

variable "search_volume_size" {
  type        = number
  nullable    = false
  default     = 1024
  description = "Size (GiB) of EBS volume attached to each data node in the ElasticSearch cluster"
}

variable "search_volume_throughput" {
  type        = number
  default     = null
  description = "EBS throughput (required for some gp3 volumes)"
}

variable "search_volume_type" {
  type        = string
  nullable    = false
  default     = "gp2"
  description = "Type of EBS volumes attached to data nodes in the ElasticSearch cluster"
}

variable "template_file" {
  type        = string
  nullable    = true
  default     = null
  description = "Local file to upload to S3 to use as the CloudFormation template"
}

variable "parameters" {
  type        = map(any)
  nullable    = false
  description = "Parameters to pass to the CloudFormation stack"
}

variable "vpc_id" {
  type        = string
  default     = null
  description = "Existing VPC ID for Quilt services."
}

variable "api_endpoint" {
  type        = string
  default     = null
  description = "VPC endpoint ID for API Gateway (api-execute) for Quilt services."

}

variable "intra_subnets" {
  type        = list(string)
  default     = null
  description = "IDs for subnets that only communicate with private subnets (never the Internet)."
}

variable "private_subnets" {
  type        = list(string)
  default     = null
  description = "IDs for subnets with Internet access to reach public AWS services."
}

variable "public_subnets" {
  type        = list(string)
  default     = null
  description = "IDs for public subnets. Only needed when var.internal == false (for NAT & load balancer)."
}

variable "user_security_group" {
  type        = string
  default     = null
  description = "Security group ID for Quilt load balancer ingress. Only needed when var.create_new_vpc == false."
}

variable "user_subnets" {
  type        = list(string)
  default     = null
  description = "Subnet IDs for Quilt load balancer. Only needed when var.internal == true and var.create_new_vpc == false."
}

variable "stack_notification_arns" {
  type        = list(string)
  default     = null
  description = "A list of SNS topic ARNs to publish CloudFormation stack related events."
}

variable "create_timeout" {
  description = "aws_cloudformation_stack.timeouts.create="
  type        = string
  default     = "30m"
}

variable "delete_timeout" {
  description = "aws_cloudformation_stack.timeouts.delete="
  type        = string
  default     = "1h30m"
}

variable "update_timeout" {
  description = "aws_cloudformation_stack.timeouts.update="
  type        = string
  default     = "1h"
}

variable "on_failure" {
  description = "aws_cloudformation_stack.on_failure="
  type        = string
  default     = "ROLLBACK"
}

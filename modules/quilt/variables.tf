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
  nullable    = false
  description = "Create a new VPC if true, otherwise use an existing VPC."
}

variable "cidr" {
  type        = string
  nullable    = false
  default     = "10.0.0.0/16"
  description = "CIDR block for the VPC. Set for validation even if using an existing VPC."
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

variable "search_volume_size" {
  type        = number
  nullable    = false
  default     = 100
  description = "Size of EBS volumes attached to data nodes in the ElasticSearch cluster"
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
  description = "VPC endpoint for API Gateway (api-execute) for Quilt services."

}

variable "intra_subnets" {
  type        = list(string)
  default     = null
  description = "Only communicate with private subnets (never the Internet)."
}

variable "private_subnets" {
  type        = list(string)
  default     = null
  description = "Have Internet access to reach public AWS services."
}

variable "public_subnets" {
  type        = list(string)
  default     = null
  description = "Only needed when var.internal == false (for NAT & load balancer)."
}

variable "user_security_group" {
  type        = string
  default     = null
  description = "Quilt load balancer ingress SG when providing an existing VPC."
}

variable "user_subnets" {
  type        = list(string)
  default     = null
  description = "Quilt load balancer subnet when var.internal == true."
}

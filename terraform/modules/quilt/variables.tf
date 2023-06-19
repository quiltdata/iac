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

variable "search_instance_count" {
  type        = number
  nullable    = false
  default     = 2
  description = "Number of instances in the ElasticSearch cluster"
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
  description = "Whether dedicated main nodes are enabled for the ElasticSearch cluster"
}

variable "search_dedicated_master_count" {
  type        = number
  nullable    = false
  default     = 3
  description = "Number of dedicated main nodes in the ElasticSearch cluster"
}

variable "search_dedicated_master_type" {
  type        = string
  nullable    = false
  default     = "m5.large.elasticsearch"
  description = "Instance type of the dedicated main nodes in the ElasticSearch cluster"
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

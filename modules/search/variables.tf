variable "domain_name" {
  type     = string
  nullable = false
}

variable "vpc_id" {
  type     = string
  nullable = false
}

variable "subnet_ids" {
  type     = list(string)
  nullable = false
}

variable "auto_tune_desired_state" {
  type     = string
  nullable = false
}

variable "instance_count" {
  type     = number
  nullable = false
}

variable "instance_type" {
  type     = string
  nullable = false
}

variable "dedicated_master_enabled" {
  type     = bool
  nullable = false
}

variable "dedicated_master_count" {
  type     = number
  nullable = false
}

variable "dedicated_master_type" {
  type     = string
  nullable = false
}

variable "zone_awareness_enabled" {
  type     = bool
  nullable = false
}

variable "volume_iops" {
  type    = number
  default = null
}

variable "volume_size" {
  type     = number
  nullable = false
}

variable "volume_type" {
  type     = string
  nullable = false
}

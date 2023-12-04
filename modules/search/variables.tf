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
  type        = number
  description = "Must be null or an integer greater than or equal to 3000."
  validation {
    condition     = try(var.volume_iops >= 3000, var.volume_iops == null, false)
    error_message = "Invalid volume_iops"
  }
}

variable "volume_size" {
  type     = number
  nullable = false
}

variable "volume_throughput" {
  type = number
  description = "EBS throughput (for some gp3 volumes)"
}

variable "volume_type" {
  type     = string
  nullable = false
}

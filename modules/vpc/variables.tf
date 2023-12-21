variable "name" {
  type     = string
  nullable = false
}

variable "create_new_vpc" {
  type        = bool
  nullable    = false
  description = "Create a new VPC if true, otherwise use an existing VPC."
}

variable "cidr" {
  type     = string
  nullable = false
  validation {
    condition     = split("/", var.cidr)[1] < 22
    error_message = "CIDR prefix should allow for at least 1,024 IP addresses"
  }
}

variable "internal" {
  type     = bool
  nullable = false
}

variable "existing_vpc_id" {
  type = string
}

variable "existing_api_endpoint" {
  type = string
}

variable "existing_intra_subnets" {
  type = list(string)
  validation {
    condition     = var.existing_intra_subnets == null ? true : length(var.existing_intra_subnets) == 2
    error_message = "Must contain 2 string ids or be null."
  }
}

variable "existing_private_subnets" {
  type = list(string)
  validation {
    condition     = var.existing_private_subnets == null ? true : length(var.existing_private_subnets) == 2
    error_message = "Must contain 2 string ids or be null."
  }
}

variable "existing_public_subnets" {
  type = list(string)
  validation {
    condition     = var.existing_public_subnets == null ? true : length(var.existing_public_subnets) == 2
    error_message = "Must contain 2 string ids or be null."
  }
}

variable "existing_user_security_group" {
  type        = string
  description = "Security group id to customize Quilt load balancer access. Must allow ingress from Quilt catalog users on port 443."
}

variable "existing_user_subnets" {
  type        = list(string)
  description = "Subnet ids for Quilt load balancer. Must be reachable by Quilt catalog users."
  validation {
    condition     = var.existing_user_subnets == null ? true : length(var.existing_user_subnets) == 2
    error_message = "Must contain 2 string ids or be null."
  }
}

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
    condition     = split("/", var.cidr)[1] <= 24
    error_message = "CIDR prefix should allow for at least 256 IPv4 addresses"
  }
}

variable "internal" {
  type     = bool
  nullable = false
}

variable "transit_gateway_id" {
  type        = string
  default     = null
  description = "Transit Gateway ID for private subnet egress. Only supported when create_new_vpc == true. If set, NAT gateways and IPv6 egress-only gateways are disabled."
  validation {
    condition     = var.transit_gateway_id == null || can(regex("^tgw-[0-9a-f]+$", var.transit_gateway_id))
    error_message = "transit_gateway_id must be null or a valid Transit Gateway ID (e.g. tgw-0123456789abcdef0)."
  }
}

variable "transit_gateway_ipv6_egress" {
  type        = bool
  default     = false
  description = "When transit_gateway_id is set, also route the private subnets' IPv6 default route (::/0) through the Transit Gateway. Leave false unless the Transit Gateway is configured for IPv6 egress; otherwise IPv6 traffic would be black-holed (with no route, IPv4 still falls back cleanly). No effect when transit_gateway_id is null."
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

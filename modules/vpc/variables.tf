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

variable "enable_transit_gateway" {
  type        = bool
  default     = false
  description = "Route private subnet egress through a Transit Gateway instead of NAT gateways. Only supported when create_new_vpc == true. When true, transit_gateway_id is required, and NAT gateways and the IPv6 egress-only gateway are disabled. (Toggle is a separate bool so transit_gateway_id may be a value known only after apply, e.g. a TGW created in the same configuration.)"
}

variable "transit_gateway_id" {
  type        = string
  default     = null
  description = "Transit Gateway ID for private subnet egress. Required when enable_transit_gateway == true; may be a computed value (e.g. a TGW created in the same configuration)."
  validation {
    condition     = var.transit_gateway_id == null || can(regex("^tgw-[0-9a-f]+$", var.transit_gateway_id))
    error_message = "transit_gateway_id must be null or a valid Transit Gateway ID (e.g. tgw-0123456789abcdef0)."
  }
}

variable "transit_gateway_ipv6_egress" {
  type        = bool
  default     = false
  description = "When enable_transit_gateway is true, also route IPv6 (::/0) egress through the Transit Gateway. Set true only if the Transit Gateway carries IPv6 egress: pointing ::/0 at a TGW that can't route IPv6 black-holes the traffic and stalls clients without Happy Eyeballs (e.g. Python requests/urllib3) on the connection timeout. Left false (default), the VPC has no IPv6 default route, so IPv6 attempts fail immediately and clients use IPv4 with no delay. No effect when enable_transit_gateway is false."
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

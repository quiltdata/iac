variable "name" {
  type     = string
  nullable = false
}

variable "cidr" {
  type     = string
  nullable = false
  validation {
    condition     = split("/", var.cidr)[1] < 21
    error_message = "cidr prefix should allow for at least 1,024 IP addresses"
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
}

variable "existing_private_subnets" {
  type = list(string)
}

variable "existing_public_subnets" {
  type = list(string)
}

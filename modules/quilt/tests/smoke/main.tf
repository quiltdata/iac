# Wrapper root for the `quilt` module smoke tests.
#
# The smoke tests run against this wrapper rather than modules/quilt directly
# because the quilt module's `stack` output embeds sensitive values (DB + admin
# passwords); as a root module under test that trips a sensitive-output error.
# The wrapper re-exposes only the non-sensitive stack name.
#
# The required_providers block below is also load-bearing for the tests:
# declaring the provider requirement at the root is what lets the test's
# mock_provider engage for the whole module tree. Without a direct provider
# reference at the root, the mock never attaches and the child modules fall
# back to real AWS credentials.
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Match what the modules under test transitively require: the
      # terraform-aws-modules/vpc ~> 6.0 module needs aws >= 6.28. Pinning keeps
      # CI deterministic and off a future major.
      version = "~> 6.0"
    }
  }
}

variable "create_new_vpc" {
  type = bool
}

variable "internal" {
  type    = bool
  default = false
}

variable "vpc_id" {
  type    = string
  default = null
}

variable "api_endpoint" {
  type    = string
  default = null
}

variable "intra_subnets" {
  type    = list(string)
  default = null
}

variable "private_subnets" {
  type    = list(string)
  default = null
}

variable "public_subnets" {
  type    = list(string)
  default = null
}

variable "user_security_group" {
  type    = string
  default = null
}

variable "user_subnets" {
  type    = list(string)
  default = null
}

variable "enable_transit_gateway" {
  type    = bool
  default = false
}

variable "transit_gateway_id" {
  type    = string
  default = null
}

variable "transit_gateway_ipv6_egress" {
  type    = bool
  default = false
}

# New inputs added to the quilt module must be threaded through here, or the
# smoke coverage silently narrows (the new input is never exercised).
module "quilt" {
  source = "../../"

  name                        = "quilt-test"
  parameters                  = {}
  template_file               = "${path.module}/fixtures/quilt.yaml"
  enable_transit_gateway      = var.enable_transit_gateway
  transit_gateway_id          = var.transit_gateway_id
  transit_gateway_ipv6_egress = var.transit_gateway_ipv6_egress

  create_new_vpc      = var.create_new_vpc
  internal            = var.internal
  vpc_id              = var.vpc_id
  api_endpoint        = var.api_endpoint
  intra_subnets       = var.intra_subnets
  private_subnets     = var.private_subnets
  public_subnets      = var.public_subnets
  user_security_group = var.user_security_group
  user_subnets        = var.user_subnets
}

# Compose `cnames` with `quilt` so CI's init resolves both modules' AWS
# provider constraints together — a future incompatible pin fails init here.
# Inputs are literal dummies; this guards resolution, not value flow.
module "cnames" {
  source = "../../../cnames"

  zone_id        = "Z00000000000000000000"
  quilt_web_host = "quilt-test.example.com"
  lb_dns_name    = "test-lb.example.com"
}

# Re-expose ONLY the non-sensitive stack name. Do not output module.quilt.stack
# (it embeds the DB URL + admin password) or any *_password value — a sensitive
# root output makes `terraform test` fail, which is the whole reason this
# wrapper exists.
output "stack_name" {
  value = module.quilt.stack.name
}

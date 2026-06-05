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

module "quilt" {
  source = "../../"

  name          = "quilt-test"
  parameters    = {}
  template_file = "${path.module}/fixtures/quilt.yaml"

  create_new_vpc      = var.create_new_vpc
  internal            = var.internal
  vpc_id              = var.vpc_id
  intra_subnets       = var.intra_subnets
  private_subnets     = var.private_subnets
  public_subnets      = var.public_subnets
  user_security_group = var.user_security_group
}

output "stack_name" {
  value = module.quilt.stack.name
}

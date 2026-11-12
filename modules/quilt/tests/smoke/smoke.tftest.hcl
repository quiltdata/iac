# Smoke tests for the public `quilt` module, run against the wrapper root in
# this directory (see main.tf).
#
# Plan-only with the AWS provider mocked: no credentials, no infrastructure.
# Exercises the full wiring (vpc + db + search + the CloudFormation stack), so
# a change that breaks the public boundary or the vpc pass-through fails in CI.
# The wrapper also composes the `cnames` module (see main.tf), so an AWS
# provider constraint that can't resolve across quilt + cnames fails at init.
#
# Assertions reference known inputs (the stack name), not mocked computed
# attributes, whose generated values are intentionally arbitrary.

mock_provider "aws" {
  # slice(..., 0, 2) and the cidrsubnet math in the vpc submodule need at
  # least two AZ names; mocked collections are otherwise empty.
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b", "us-east-1c"]
    }
  }
}

run "new_vpc_plans" {
  command = plan
  variables {
    create_new_vpc = true
    internal       = false
  }
  assert {
    condition     = output.stack_name == "quilt-test"
    error_message = "The CloudFormation stack must be named after var.name"
  }
  # The template tags the stack's own resources; a stack-level tag would be a
  # second writer of the same key on them.
  assert {
    condition     = try(output.stack_tags["aws-apn-id-730278974607"], null) == null
    error_message = "The stack must not carry the partner tag"
  }
}

# Targets the module itself, since expect_failures can name only the root's
# variables.
run "pc_prefixed_product_code_is_rejected" {
  command = plan
  module {
    source = "../.."
  }
  variables {
    name                     = "quilt-test"
    parameters               = {}
    template_file            = "fixtures/quilt.yaml"
    internal                 = false
    create_new_vpc           = true
    marketplace_product_code = "pc:1xn1f7bxkj2dc16ak28s0dbgk"
  }
  expect_failures = [var.marketplace_product_code]
}

run "new_vpc_transit_gateway_plans" {
  command = plan
  variables {
    create_new_vpc         = true
    internal               = false
    enable_transit_gateway = true
    transit_gateway_id     = "tgw-00000000000000000"
  }
  # TGW egress mode on a new VPC must plan end-to-end through the public module.
  assert {
    condition     = output.stack_name == "quilt-test"
    error_message = "The CloudFormation stack must be named after var.name"
  }
}

run "new_vpc_transit_gateway_ipv6_plans" {
  command = plan
  variables {
    create_new_vpc              = true
    internal                    = false
    enable_transit_gateway      = true
    transit_gateway_id          = "tgw-00000000000000000"
    transit_gateway_ipv6_egress = true
  }
  # TGW egress with IPv6 opted in must also plan end-to-end.
  assert {
    condition     = output.stack_name == "quilt-test"
    error_message = "The CloudFormation stack must be named after var.name"
  }
}

run "new_vpc_internal_plans" {
  command = plan
  variables {
    create_new_vpc = true
    internal       = true
  }
  # internal = true exercises the most conditional wiring in quilt/main.tf:
  # the PublicSubnets/UserSubnets null-coalescing and the internal-gated api
  # endpoint.
  assert {
    condition     = output.stack_name == "quilt-test"
    error_message = "The CloudFormation stack must be named after var.name"
  }
}

run "existing_vpc_plans" {
  command = plan
  variables {
    create_new_vpc      = false
    internal            = false
    vpc_id              = "vpc-00000000000000000"
    intra_subnets       = ["subnet-intra-a", "subnet-intra-b"]
    private_subnets     = ["subnet-priv-a", "subnet-priv-b"]
    public_subnets      = ["subnet-pub-a", "subnet-pub-b"]
    user_security_group = "sg-00000000000000000"
  }
  assert {
    condition     = output.stack_name == "quilt-test"
    error_message = "The CloudFormation stack must be named after var.name"
  }
}

run "existing_vpc_internal_plans" {
  command = plan
  variables {
    create_new_vpc      = false
    internal            = true
    vpc_id              = "vpc-00000000000000000"
    api_endpoint        = "vpce-00000000000000000"
    intra_subnets       = ["subnet-intra-a", "subnet-intra-b"]
    private_subnets     = ["subnet-priv-a", "subnet-priv-b"]
    public_subnets      = null
    user_security_group = "sg-00000000000000000"
    user_subnets        = ["subnet-user-a", "subnet-user-b"]
  }
  # internal = true on the existing-VPC path exercises quilt's pass-through of
  # api_endpoint + user_subnets and the internal-gated CFN wiring.
  assert {
    condition     = output.stack_name == "quilt-test"
    error_message = "The CloudFormation stack must be named after var.name"
  }
}

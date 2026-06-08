# Characterization tests for the new-vs-existing VPC input validation.
#
# These run `terraform plan` with the AWS provider mocked, so they need no AWS
# credentials and create no infrastructure. They pin the behavior of the
# `configuration_error` precondition (see outputs.tf): valid input combinations
# must plan cleanly, and contradictory combinations must fail fast.
#
# On a valid config the precondition passes and the `configuration_error`
# output renders the requirement checklist with every line marked ✅; an
# unmet requirement shows ❌ and a contradictory config trips the precondition
# during plan.

mock_provider "aws" {
  # slice(..., 0, 2) and the cidrsubnet math need at least two AZ names.
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b", "us-east-1c"]
    }
  }
}

variables {
  name = "quilt-test"
  cidr = "10.0.0.0/16"
}

# --- Valid: create a new VPC -------------------------------------------------

run "new_vpc_external_alb" {
  command = plan

  variables {
    create_new_vpc               = true
    internal                     = false
    existing_vpc_id              = null
    existing_api_endpoint        = null
    existing_intra_subnets       = null
    existing_private_subnets     = null
    existing_public_subnets      = null
    existing_user_security_group = null
    existing_user_subnets        = null
  }

  assert {
    condition     = strcontains(output.configuration_error, "create a new VPC")
    error_message = "New-VPC config must be checked against the new-network requirements"
  }

  assert {
    condition     = !strcontains(output.configuration_error, "❌")
    error_message = "A valid new-VPC config (internal = false) must satisfy every requirement"
  }
}

run "new_vpc_internal_alb" {
  command = plan

  variables {
    create_new_vpc               = true
    internal                     = true
    existing_vpc_id              = null
    existing_api_endpoint        = null
    existing_intra_subnets       = null
    existing_private_subnets     = null
    existing_public_subnets      = null
    existing_user_security_group = null
    existing_user_subnets        = null
  }

  assert {
    condition     = strcontains(output.configuration_error, "create a new VPC")
    error_message = "New-VPC config must be checked against the new-network requirements"
  }

  assert {
    condition     = !strcontains(output.configuration_error, "❌")
    error_message = "A valid new-VPC config (internal = true) must satisfy every requirement"
  }
}

# --- Valid: use an existing VPC ----------------------------------------------

run "existing_vpc_external_alb" {
  command = plan

  variables {
    create_new_vpc               = false
    internal                     = false
    existing_vpc_id              = "vpc-00000000000000000"
    existing_api_endpoint        = null
    existing_intra_subnets       = ["subnet-intra-a", "subnet-intra-b"]
    existing_private_subnets     = ["subnet-priv-a", "subnet-priv-b"]
    existing_public_subnets      = ["subnet-pub-a", "subnet-pub-b"]
    existing_user_security_group = "sg-00000000000000000"
    existing_user_subnets        = null
  }

  assert {
    condition     = strcontains(output.configuration_error, "use an existing VPC")
    error_message = "Existing-VPC config must be checked against the existing-network requirements"
  }

  assert {
    condition     = !strcontains(output.configuration_error, "❌")
    error_message = "A valid existing-VPC config (internal = false) must satisfy every requirement"
  }

  assert {
    condition     = output.vpc_id == "vpc-00000000000000000"
    error_message = "Existing-VPC mode must surface the supplied existing_vpc_id"
  }
}

run "existing_vpc_internal_alb" {
  command = plan

  variables {
    create_new_vpc               = false
    internal                     = true
    existing_vpc_id              = "vpc-00000000000000000"
    existing_api_endpoint        = "vpce-00000000000000000"
    existing_intra_subnets       = ["subnet-intra-a", "subnet-intra-b"]
    existing_private_subnets     = ["subnet-priv-a", "subnet-priv-b"]
    existing_public_subnets      = null
    existing_user_security_group = "sg-00000000000000000"
    existing_user_subnets        = ["subnet-user-a", "subnet-user-b"]
  }

  assert {
    condition     = strcontains(output.configuration_error, "use an existing VPC")
    error_message = "Existing-VPC config must be checked against the existing-network requirements"
  }

  assert {
    condition     = !strcontains(output.configuration_error, "❌")
    error_message = "A valid existing-VPC config (internal = true) must satisfy every requirement"
  }

  assert {
    condition     = output.vpc_id == "vpc-00000000000000000"
    error_message = "Existing-VPC mode must surface the supplied existing_vpc_id"
  }
}

# --- Invalid: contradictory input must fail fast -----------------------------

run "new_vpc_with_existing_id_is_rejected" {
  command = plan

  variables {
    create_new_vpc               = true
    internal                     = false
    existing_vpc_id              = "vpc-00000000000000000"
    existing_api_endpoint        = null
    existing_intra_subnets       = null
    existing_private_subnets     = null
    existing_public_subnets      = null
    existing_user_security_group = null
    existing_user_subnets        = null
  }

  # create_new_vpc = true while supplying an existing VPC id satisfies neither
  # the new-network nor the existing-network requirement set.
  expect_failures = [output.configuration_error]
}

run "existing_vpc_missing_inputs_is_rejected" {
  command = plan

  variables {
    create_new_vpc               = false
    internal                     = false
    existing_vpc_id              = "vpc-00000000000000000"
    existing_api_endpoint        = null
    existing_intra_subnets       = null
    existing_private_subnets     = null
    existing_public_subnets      = null
    existing_user_security_group = null
    existing_user_subnets        = null
  }

  # create_new_vpc = false without the required existing_* inputs is incomplete.
  expect_failures = [output.configuration_error]
}

# --- Transit Gateway egress mode --------------------------------------------

run "new_vpc_with_transit_gateway" {
  command = plan

  variables {
    create_new_vpc               = true
    internal                     = false
    transit_gateway_id           = "tgw-00000000000000000"
    existing_vpc_id              = null
    existing_api_endpoint        = null
    existing_intra_subnets       = null
    existing_private_subnets     = null
    existing_public_subnets      = null
    existing_user_security_group = null
    existing_user_subnets        = null
  }

  # A new VPC with a transit_gateway_id is the supported TGW egress mode and
  # must plan cleanly.
  assert {
    condition     = !strcontains(output.configuration_error, "❌")
    error_message = "A new VPC with transit_gateway_id must satisfy every requirement"
  }

  # The TGW attachment and the IPv4 default egress route must be planned,
  # pointed at the supplied gateway.
  assert {
    condition     = length(aws_ec2_transit_gateway_vpc_attachment.egress) == 1
    error_message = "Exactly one TGW VPC attachment must be created"
  }

  assert {
    condition     = aws_ec2_transit_gateway_vpc_attachment.egress[0].transit_gateway_id == "tgw-00000000000000000"
    error_message = "The TGW attachment must target the supplied transit_gateway_id"
  }

  assert {
    condition     = length(aws_route.private_tgw_ipv4_egress) > 0
    error_message = "IPv4 default egress routes to the TGW must be planned"
  }

  # IPv6 egress via the TGW is opt-in (transit_gateway_ipv6_egress, default
  # false). With it off, no ::/0 route is created and the attachment does not
  # advertise IPv6 support, so IPv6 traffic is not black-holed at the TGW.
  assert {
    condition     = length(aws_route.private_tgw_ipv6_egress) == 0
    error_message = "No IPv6 egress route should be planned when transit_gateway_ipv6_egress is false"
  }

  assert {
    condition     = aws_ec2_transit_gateway_vpc_attachment.egress[0].ipv6_support == "disable"
    error_message = "The TGW attachment must not advertise IPv6 support when transit_gateway_ipv6_egress is false"
  }
}

run "new_vpc_with_transit_gateway_ipv6_egress" {
  command = plan

  variables {
    create_new_vpc               = true
    internal                     = false
    transit_gateway_id           = "tgw-00000000000000000"
    transit_gateway_ipv6_egress  = true
    existing_vpc_id              = null
    existing_api_endpoint        = null
    existing_intra_subnets       = null
    existing_private_subnets     = null
    existing_public_subnets      = null
    existing_user_security_group = null
    existing_user_subnets        = null
  }

  # Opting in routes the IPv6 default route through the TGW and enables IPv6
  # support on the attachment.
  assert {
    condition     = length(aws_route.private_tgw_ipv6_egress) > 0
    error_message = "IPv6 egress routes to the TGW must be planned when transit_gateway_ipv6_egress is true"
  }

  assert {
    condition     = aws_ec2_transit_gateway_vpc_attachment.egress[0].ipv6_support == "enable"
    error_message = "The TGW attachment must advertise IPv6 support when transit_gateway_ipv6_egress is true"
  }
}

run "existing_vpc_with_transit_gateway_is_rejected" {
  command = plan

  variables {
    create_new_vpc               = false
    internal                     = false
    transit_gateway_id           = "tgw-00000000000000000"
    existing_vpc_id              = "vpc-00000000000000000"
    existing_api_endpoint        = null
    existing_intra_subnets       = ["subnet-intra-a", "subnet-intra-b"]
    existing_private_subnets     = ["subnet-priv-a", "subnet-priv-b"]
    existing_public_subnets      = ["subnet-pub-a", "subnet-pub-b"]
    existing_user_security_group = "sg-00000000000000000"
    existing_user_subnets        = null
  }

  # transit_gateway_id is only supported with create_new_vpc = true; combining
  # it with an existing VPC must fail fast rather than silently ignore the id.
  expect_failures = [output.configuration_error]
}

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
    condition     = !strcontains(output.configuration_error, "❌")
    error_message = "A valid existing-VPC config (internal = true) must satisfy every requirement"
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

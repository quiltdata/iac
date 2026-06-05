# Smoke tests for the public `quilt` module, run against the wrapper root in
# this directory (see main.tf).
#
# Plan-only with the AWS provider mocked: no credentials, no infrastructure.
# Exercises the full wiring (vpc + db + search + the CloudFormation stack), so
# a change that breaks the public boundary or the vpc pass-through fails in CI.
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

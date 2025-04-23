terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"  # or your preferred region
}

module "test_stack" {
  source = "../modules/quilt"
  
  name = "test-stack"
  cidr = "10.0.0.0/16"
  internal = false
  create_new_vpc = true
  template_file = "${path.module}/test.yml"
  
  parameters = {
    AdminEmail = "test@example.com"
  }
}

locals {
  test_tags = {
    test_common_tags = (
      module.test_stack.common_tags == {
        "quilt:stack-name" = "test-stack"
      }
    )
    
    test_stack_dependent_tags = (
      module.test_stack.stack_dependent_tags == {
        "quilt:stack-name" = "test-stack"
        "quilt:stack-id"   = module.test_stack.stack_id
      }
    )
  }
}

output "test_common_tags" {
  value = local.test_tags.test_common_tags
}

output "test_stack_dependent_tags" {
  value = local.test_tags.test_stack_dependent_tags
}

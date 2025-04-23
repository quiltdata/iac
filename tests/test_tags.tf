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

# Use minimal test configuration to avoid long-running resource creation
module "test_stack" {
  source = "../modules/quilt"
  
  name = "test-stack"
  cidr = "10.0.0.0/16"
  internal = false
  create_new_vpc = true
  template_file = "${path.module}/test.yml"

  # Enable force destroy for testing
  on_failure = "DELETE"

  # Minimize resource sizes and enable cleanup
  db_instance_class = "db.t3.micro"
  db_multi_az = false
  db_deletion_protection = false
  
  search_instance_count = 1
  search_instance_type = "t3.small.elasticsearch"
  search_dedicated_master_enabled = false
  search_zone_awareness_enabled = false
  search_volume_size = 10
  
  parameters = {
    AdminEmail = "test@example.com"
  }

  # Add shorter timeouts
  create_timeout = "20m"
  update_timeout = "20m"
  delete_timeout = "20m"
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
  description = "Test result for common tags"
}

output "test_stack_dependent_tags" {
  value = local.test_tags.test_stack_dependent_tags
  description = "Test result for stack dependent tags"
  sensitive = false
}

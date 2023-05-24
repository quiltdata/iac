provider "aws" {
  region              = "EXAMPLE"
  allowed_account_ids = ["EXAMPLE"]
}

resource "random_password" "db_password" {
  length  = 16
  special = false
}

resource "random_password" "admin_password" {
  length = 16
}


locals {
  private_subnets = join(",", ["subnet-1", "subnet-2"])
  public_subnets  = join(",", ["subnet-3", "subnet-4"])
  hostname_parts  = split(".", var.parameters["QuiltWebHost"])
  domain_parts    = regex("^(.*?)(\\..*)", var.parameters["QuiltWebHost"])
  domain_first    = local.domain_parts[0]
  domain_rest     = local.domain_parts[1]
  build_file      = "LOCAL/PATH/TO/TEMPLATE.yaml"
}


module "instance" {
  source = "../.."
  # In order to perform a stack update, replace the contents
  # at this URL; changing the URL will plan to recreate the entire stack
  template_url = "https://EXAMPLE.com/foo/bar/template.yaml"
  stack_name   = "EXAMPLE"
  parameters = merge(
    var.parameters,
    # these are here because you can't do dynamic stuff in variables.tf
    {
      AdminPassword = random_password.admin_password.result
      DBPassword    = random_password.db_password.result
      Subnets       = "EXAMPLE1,EXAMPLE2"
    }
  )

  user_tags = {
    Author      = "EXAMPLE"
    Description = "EXAMPLE"
  }
}

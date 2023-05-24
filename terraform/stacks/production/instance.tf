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
  build_file      = "../../cftemplates/example.yaml"
}

resource "aws_s3_object" "cft" {
  bucket = "EXAMPLE"
  key    = "EXAMPLE.yaml"
  source = local.build_file
  etag   = filemd5(local.build_file)
}

resource "aws_s3_bucket" "test_bucket" {
  bucket = "test-bucket-${module.instance.stack_name}"
}

module "instance" {
  source = "../.."
  # In order to perform a stack update, replace the contents
  # at this URL; changing the URL will plan to recreate the entire stack
  template_url = "https://EXAMPLE.yaml"
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

output "host" { value = "https://${var.parameters["QuiltWebHost"]}" }
output "bucket_name" { value = aws_s3_bucket.test_bucket.bucket }

resource "aws_route53_record" "catalog" {
  depends_on = [module.instance]
  zone_id    = "EXAMPLE"
  name       = var.parameters["QuiltWebHost"]
  type       = "CNAME"
  ttl        = 60
  records = [
    module.instance.alb_dns_name
  ]
}

resource "aws_route53_record" "registry" {
  depends_on = [module.instance]
  zone_id    = "EXAMPLE"
  name       = format("%s-registry%s", local.domain_first, local.domain_rest)
  type       = "CNAME"
  ttl        = 60
  records = [
    module.instance.alb_dns_name
  ]
}

resource "aws_route53_record" "s3-proxy" {
  depends_on = [module.instance]
  zone_id    = "EXAMPLE"
  name       = format("%s-s3-proxy%s", local.domain_first, local.domain_rest)
  type       = "CNAME"
  ttl        = 60
  records = [
    module.instance.alb_dns_name
  ]
}

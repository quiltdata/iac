terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Span 5.x and 6.x: this module only manages aws_route53_record (stable
      # across both majors), and it is used alongside the vpc module, whose
      # terraform-aws-modules/vpc ~> 6.0 dependency requires aws >= 6.28. A
      # ~> 5.0 pin here made `quilt` + `cnames` unresolvable in one root.
      version = ">= 5.79, < 7.0"
    }
  }
}

locals {
  match     = regex("^([^.]+)(\\..*)$", var.quilt_web_host)
  subdomain = local.match[0]
  remainder = local.match[1]
}

resource "aws_route53_record" "cnames" {
  for_each = toset(["", "-registry", "-s3-proxy"])
  zone_id  = var.zone_id
  name     = format("%s%s%s", local.subdomain, each.key, local.remainder)
  type     = "CNAME"
  ttl      = var.ttl
  records  = [var.lb_dns_name]
}

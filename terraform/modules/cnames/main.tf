locals {
  type = "CNAME"
  match = regex("(^[^.]+)(\\..*)", var.lb_dns_name)
  subdomain = local.match[0]
  remainder = local.match[1]
}

resource "aws_route53_record" "cnames" {
  for_each = toset(["", "-registry", "-s3-proxy"])
  zone_id = var.zone_id
  name    = format("%s%s%s", local.subdomain, each.key, local.remainder)
  type    = local.type
  ttl     = var.ttl
  records = [var.lb_dns_name]
}
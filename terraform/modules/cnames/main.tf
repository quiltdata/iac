locals {
  type = "CNAME"
}
resource "aws_route53_record" "catalog" {
  zone_id    = var.zone_id
  name       = var.parameters["QuiltWebHost"]
  type       = local.type
  ttl        = var.ttl
  records = [
    var.lb_dns_name
  ]
}

resource "aws_route53_record" "registry" {
  zone_id    = var.zone_id
  name       = format("%s-registry%s", local.domain_first, local.domain_rest)
  type       = local.type
  ttl        = var.ttl
  records = [
    var.lb_dns_name
  ]
}

resource "aws_route53_record" "s3-proxy" {
  zone_id    = var.zone_id
  name       = format("%s-s3-proxy%s", local.domain_first, local.domain_rest)
  type       = local.type
  ttl        = var.ttl
  records = [
    var.lb_dns_name
  ]
}

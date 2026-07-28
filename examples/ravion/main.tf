# Example root config for the Ravion module definition (module.yaml) in this
# directory. Ravion renders module.yaml's typed inputs into the variables
# below and supplies certificate_arn / zone_id / lb_dns_name by resolving
# the certificate / dns refs against the modules those refs point to — which
# may live in a different Ravion-connected AWS account than this one (see
# README.md).
#
# modules/quilt and modules/cnames are used completely unmodified.

terraform {
  required_version = ">= 1.10.0"
  required_providers {
    http  = { source = "hashicorp/http" }
    local = { source = "hashicorp/local" }
  }
}

variable "name" {
  type        = string
  description = "Stack name (<=20 chars, lowercase alphanumeric + hyphens)."
}

variable "template_url" {
  type        = string
  description = "URL of the published Quilt CloudFormation template. Fetched at apply time; never committed."
}

# modules/quilt's template_file input takes a local path — it's uploaded to
# a per-install S3 bucket and hashed via filemd5() — so template_url has to
# be fetched and written to a local file before it reaches module "quilt"
# below; passing the URL straight through fails filemd5() on a URL string.
data "http" "template" {
  url = var.template_url
}

resource "local_file" "template" {
  filename        = "${path.module}/.quilt-template-${md5(var.template_url)}.yaml"
  content         = data.http.template.response_body
  file_permission = "0600"
}

variable "catalog_domain" {
  type        = string
  description = "Public hostname for the Quilt catalog."
}

variable "admin_email" {
  type        = string
  description = "Initial admin account email address."
}

variable "sizing" {
  type    = string
  default = "medium"
}

variable "internal" {
  type    = bool
  default = false
}

variable "create_new_vpc" {
  type    = bool
  default = true
}

# Supplied by Ravion when create_new_vpc = false, resolved from the vpc ref.
variable "vpc_id" {
  type    = string
  default = null
}

# Supplied by Ravion, resolved from the certificate ref. Ravion is responsible
# for confirming the certificate's SANs cover all of local.hostnames before
# this config ever runs.
variable "certificate_arn" {
  type        = string
  description = "ACM certificate ARN, resolved by Ravion from the certificate ref."
}

# Supplied by Ravion, resolved from the dns ref. May belong to a different
# AWS account than the one this stack deploys into.
variable "zone_id" {
  type        = string
  description = "Route53 hosted zone ID, resolved by Ravion from the dns ref."
}

locals {
  # Quilt's hostname contract: the catalog host plus its derived registry
  # and s3-proxy siblings. The referenced certificate must cover all three.
  match     = regex("^([^.]+)(\\..*)$", var.catalog_domain)
  subdomain = local.match[0]
  remainder = local.match[1]
  hostnames = [
    var.catalog_domain,
    "${local.subdomain}-registry${local.remainder}",
    "${local.subdomain}-s3-proxy${local.remainder}",
  ]

  sizing_profiles = {
    small = {
      search_dedicated_master_enabled = false
      search_zone_awareness_enabled   = false
      search_instance_count           = 1
      search_instance_type            = "m6g.large.elasticsearch"
      search_volume_size              = 512
      db_instance_class               = "db.t3.small"
    }
    medium = {
      search_dedicated_master_enabled = true
      search_zone_awareness_enabled   = true
      search_instance_count           = 2
      search_instance_type            = "m6g.xlarge.elasticsearch"
      search_volume_size              = 1024
      db_instance_class               = "db.t3.medium"
    }
    large = {
      search_dedicated_master_enabled = true
      search_zone_awareness_enabled   = true
      search_instance_count           = 2
      search_instance_type            = "m6g.xlarge.elasticsearch"
      search_volume_size              = 2048
      db_instance_class               = "db.r6g.large"
    }
    xlarge = {
      search_dedicated_master_enabled = true
      search_zone_awareness_enabled   = true
      search_instance_count           = 2
      search_instance_type            = "m6g.2xlarge.elasticsearch"
      search_volume_size              = 3072
      db_instance_class               = "db.r6g.xlarge"
    }
  }

  profile = local.sizing_profiles[var.sizing]
}

module "quilt" {
  source = "github.com/quiltdata/iac//modules/quilt?ref=1.8.0"

  name          = var.name
  template_file = local_file.template.filename

  internal       = var.internal
  create_new_vpc = var.create_new_vpc
  cidr           = "10.0.0.0/16"
  vpc_id         = var.create_new_vpc ? null : var.vpc_id

  db_instance_class      = local.profile.db_instance_class
  db_multi_az            = true
  db_deletion_protection = true

  search_dedicated_master_enabled = local.profile.search_dedicated_master_enabled
  search_zone_awareness_enabled   = local.profile.search_zone_awareness_enabled
  search_instance_count           = local.profile.search_instance_count
  search_instance_type            = local.profile.search_instance_type
  search_volume_size              = local.profile.search_volume_size
  search_volume_type              = "gp3"

  parameters = {
    AdminEmail        = var.admin_email
    CertificateArnELB = var.certificate_arn
    QuiltWebHost      = var.catalog_domain
    PasswordAuth      = "Enabled"
  }
}

# DNS: creates the catalog + registry + s3-proxy CNAMEs once the stack's
# load balancer DNS name is known. zone_id may come from a different
# Ravion-connected account than the one hosting module.quilt — see README.
module "cnames" {
  source = "github.com/quiltdata/iac//modules/cnames?ref=1.8.0"

  lb_dns_name    = module.quilt.stack.outputs.LoadBalancerDNSName
  quilt_web_host = var.catalog_domain
  zone_id        = var.zone_id
}

output "hostnames" {
  description = "Hostnames the referenced certificate must cover."
  value       = local.hostnames
}

output "admin_password" {
  sensitive = true
  value     = module.quilt.admin_password
}

output "db_password" {
  sensitive = true
  value     = module.quilt.db_password
}

output "quilt_url" {
  value = "https://${var.catalog_domain}"
}

output "load_balancer_dns" {
  value = module.quilt.stack.outputs.LoadBalancerDNSName
}

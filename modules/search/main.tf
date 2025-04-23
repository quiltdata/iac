module "search_accessor_security_group" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "${var.domain_name}-search-accessor"
  description = "For resources that need access to search cluster"
  vpc_id      = var.vpc_id

  tags = local.stack_dependent_tags

  egress_with_source_security_group_id = [
    {
      rule                     = "https-443-tcp"
      source_security_group_id = module.search_security_group.security_group_id
    }
  ]
}

module "search_security_group" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "${var.domain_name}-search"
  description = "For search cluster resources"
  vpc_id      = var.vpc_id

  tags = local.stack_dependent_tags

  ingress_with_source_security_group_id = [
    {
      rule                     = "https-443-tcp"
      source_security_group_id = module.search_accessor_security_group.security_group_id
    }
  ]
}

resource "aws_elasticsearch_domain" "search" {
  domain_name           = var.domain_name
  elasticsearch_version = "6.8"

  tags = local.stack_dependent_tags

  cluster_config {
    instance_count           = var.instance_count
    instance_type            = var.instance_type
    dedicated_master_enabled = var.dedicated_master_enabled
    dedicated_master_count   = var.dedicated_master_count
    dedicated_master_type    = var.dedicated_master_type
    zone_awareness_enabled   = var.zone_awareness_enabled
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-PFS-2023-10"
  }

  ebs_options {
    ebs_enabled = true
    volume_size = var.volume_size
    volume_type = var.volume_type
    iops        = var.volume_iops
    throughput  = var.volume_throughput
  }

  encrypt_at_rest {
    enabled = true
  }

  node_to_node_encryption {
    enabled = true
  }

  vpc_options {
    subnet_ids         = var.zone_awareness_enabled ? var.subnet_ids : slice(var.subnet_ids, 0, 1)
    security_group_ids = [module.search_security_group.security_group_id]
  }
}

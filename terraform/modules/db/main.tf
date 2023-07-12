module "db_accessor_security_group" {
  source = "terraform-aws-modules/security-group/aws"

  name = "${var.identifier}-db-accessor"
  description = "For resources that need access to DB"
  vpc_id = var.vpc_id

  egress_with_source_security_group_id = [
    {
      rule = "postgresql-tcp"
      source_security_group_id = module.db_security_group.security_group_id
    }
  ]
}

module "db_security_group" {
  source = "terraform-aws-modules/security-group/aws"

  name = "${var.identifier}-db"
  description = "For DB resources"
  vpc_id = var.vpc_id

  ingress_with_source_security_group_id = [
    {
      rule = "postgresql-tcp"
      source_security_group_id = module.db_accessor_security_group.security_group_id
    }
  ]
}

module "db" {
  source = "terraform-aws-modules/rds/aws"
  version = "< 6.0.0"

  identifier = var.identifier

  snapshot_identifier = var.snapshot_identifier

  engine            = "postgres"
  engine_version    = "11.19"
  storage_type      = "gp2"
  allocated_storage = 100
  storage_encrypted = true
  instance_class    = var.instance_class
  multi_az          = var.multi_az

  apply_immediately = true

  db_name  = "quilt"
  username = "root"
  port     = "5432"

  vpc_security_group_ids = [module.db_security_group.security_group_id]
  create_db_subnet_group = true
  subnet_ids             = var.subnet_ids
  network_type           = "DUAL"

  create_db_option_group    = false
  create_db_parameter_group = false

  backup_retention_period = var.backup_retention_period
  deletion_protection = true
}

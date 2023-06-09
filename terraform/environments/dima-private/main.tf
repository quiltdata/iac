provider "aws" {
  region              = "us-east-2"
  allowed_account_ids = ["060758809828"]
}

locals {
  build_file = "/home/dima/src/quilt-deployment/t4/build/dima-dev-tf-private.yaml"
  bucket     = "cf-templates-2gbmksorj91d-us-east-2"
  key        = "tf/dima-dev-tf-private.yaml"
}

module "quilt" {
  source = "../../modules/quilt"

  name                   = "dima-tf-private"
  internal               = true
  db_snapshot_identifier = "first"

  template_url         = "https://${local.bucket}.s3.us-east-2.amazonaws.com/${local.key}"
  template_bucket      = local.bucket
  template_key         = local.key
  template_local_file  = local.build_file

  db_multi_az = false

  parameters = var.parameters
}

module "ssh_security_group" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "ssh"
  description = "Inbound SSH"
  vpc_id      = module.quilt.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["ssh-tcp"]

  egress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules       = ["https-443-tcp"]
}

module "bastion" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name = "bastion"

  ami = "ami-0dcbd2aa4a07a555b"

  instance_type               = "t3.micro"
  key_name                    = "dima"
  vpc_security_group_ids      = [module.ssh_security_group.security_group_id]
  subnet_id                   = module.quilt.vpc.public_subnets[0]
  associate_public_ip_address = true

  tags = {
    Name = "bastion"
  }
}

output "admin_password" {
  description = "Admin password"
  sensitive   = true
  value       = module.quilt.admin_password
}

output "db_password" {
  description = "DB password"
  sensitive   = true
  value       = module.quilt.db_password
}

output "stack_outputs" {
  description = "CloudFormation outputs"
  value       = module.quilt.stack.outputs
}

output "bastion" {
  value = module.bastion.public_ip
}

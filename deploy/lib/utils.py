"""Utility functions for deployment script."""

import json
import logging
import os
import sys
from pathlib import Path
from typing import Any, Dict

from jinja2 import Environment, FileSystemLoader, Template

# Setup logging
logger = logging.getLogger(__name__)


def setup_logging(verbose: bool = False) -> None:
    """Setup logging configuration.

    Args:
        verbose: Enable verbose (DEBUG) logging
    """
    level = logging.DEBUG if verbose else logging.INFO

    # Configure root logger
    logging.basicConfig(
        level=level,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
        handlers=[logging.StreamHandler(sys.stdout)],
    )

    # Reduce noise from boto3/botocore
    logging.getLogger("boto3").setLevel(logging.WARNING)
    logging.getLogger("botocore").setLevel(logging.WARNING)
    logging.getLogger("urllib3").setLevel(logging.WARNING)


def confirm_action(message: str) -> bool:
    """Prompt user for confirmation.

    Args:
        message: Confirmation message

    Returns:
        True if user confirms, False otherwise
    """
    response = input(f"{message} [y/N]: ").strip().lower()
    return response in ["y", "yes"]


def render_template(template_str: str, context: Dict[str, Any]) -> str:
    """Render a Jinja2 template string.

    Args:
        template_str: Template string
        context: Template context variables

    Returns:
        Rendered template
    """
    template = Template(template_str)
    return template.render(**context)


def render_template_file(template_path: Path, context: Dict[str, Any]) -> str:
    """Render a Jinja2 template file.

    Args:
        template_path: Path to template file
        context: Template context variables

    Returns:
        Rendered template
    """
    template_dir = template_path.parent
    template_name = template_path.name

    env = Environment(loader=FileSystemLoader(str(template_dir)))
    template = env.get_template(template_name)

    return template.render(**context)


def write_terraform_files(
    output_dir: Path, config: Any, pattern: str  # DeploymentConfig type
) -> None:
    """Write Terraform configuration files.

    Args:
        output_dir: Output directory for Terraform files
        config: Deployment configuration
        pattern: Deployment pattern ("external-iam" or "inline-iam")
    """
    output_dir.mkdir(parents=True, exist_ok=True)

    # Get infrastructure configuration
    infra_config = _get_infrastructure_config(config, pattern)

    # Calculate relative path to modules directory
    repo_root = Path(__file__).parent.parent.parent
    modules_dir = repo_root / "modules" / "quilt"

    # Calculate relative path from output_dir to modules_dir
    try:
        relative_module_path = os.path.relpath(modules_dir, output_dir)
    except ValueError:
        # If on different drives (Windows), use absolute path
        relative_module_path = str(modules_dir)

    infra_config["module_path"] = relative_module_path

    # Write main.tf
    main_tf = output_dir / "main.tf"
    main_tf.write_text(_generate_main_tf(infra_config, pattern))
    logger.info(f"Wrote main configuration to {main_tf}")

    # Write variables.tf (for optional secrets)
    variables_tf = output_dir / "variables.tf"
    variables_tf.write_text(_generate_variables_tf(config))
    logger.info(f"Wrote variables definition to {variables_tf}")

    # Write terraform.tfvars.json (with actual values)
    tfvars = output_dir / "terraform.tfvars.json"
    tfvars.write_text(_generate_tfvars_json(config))
    logger.info(f"Wrote variables to {tfvars}")

    # Write backend.tf (if needed)
    backend_tf = output_dir / "backend.tf"
    backend_tf.write_text(_generate_backend_tf(config))
    logger.info(f"Wrote backend configuration to {backend_tf}")


def _get_infrastructure_config(config: Any, pattern: str) -> Dict[str, Any]:
    """Get Terraform infrastructure configuration.

    This configures the Terraform module to create:
    - VPC (or use existing)
    - RDS database
    - ElasticSearch domain
    - Security groups

    Args:
        config: Deployment configuration
        pattern: Deployment pattern

    Returns:
        Infrastructure configuration dictionary
    """
    # Get template file path (local path for module to upload)
    template_file = _get_template_file_path(config, pattern)

    infra_config = {
        "name": config.deployment_name,
        "template_file": template_file,
        # Network configuration
        "create_new_vpc": False,  # Use existing VPC from config
        "vpc_id": config.vpc_id,
        "intra_subnets": config.subnet_ids[:2],  # For DB & ES
        "private_subnets": config.subnet_ids[:2],  # For app
        "public_subnets": config.subnet_ids,  # For ALB
        "user_security_group": config.security_group_ids[0] if config.security_group_ids else "",
        # Database configuration
        "db_instance_class": config.db_instance_class,
        "db_multi_az": False,  # Single-AZ for testing
        "db_deletion_protection": False,  # Allow deletion for testing
        # ElasticSearch configuration
        "search_instance_type": config.search_instance_type,
        "search_instance_count": 1,  # Single node for testing
        "search_volume_size": config.search_volume_size,
        "search_dedicated_master_enabled": False,
        "search_zone_awareness_enabled": False,
        # CloudFormation parameters (required + optional)
        "parameters": _get_cfn_parameters(config),
    }

    # Add external IAM configuration if applicable
    if pattern == "external-iam":
        # Generate S3 URL for IAM template
        bucket = config.template_bucket
        region = config.aws_region
        iam_template_url = f"https://{bucket}.s3.{region}.amazonaws.com/quilt-iam.yaml"
        infra_config["iam_template_url"] = iam_template_url

    return infra_config


def _get_template_file_path(config: Any, pattern: str) -> str:
    """Get path to CloudFormation template file.

    Returns path to local template file that will be uploaded by the quilt module.

    Args:
        config: Deployment configuration
        pattern: Deployment pattern

    Returns:
        Path to template file
    """
    # Use the template_prefix from config if available, otherwise use test/fixtures
    if hasattr(config, "template_prefix") and config.template_prefix:
        prefix = Path(config.template_prefix)
        if pattern == "external-iam":
            # Use app-only template (stable-app.yaml)
            return str(prefix) + "-app.yaml"
        else:
            # Use monolithic template (stable.yaml)
            return str(prefix) + ".yaml"
    else:
        # Default to test/fixtures path
        templates_dir = Path(__file__).parent.parent.parent / "test" / "fixtures"
        if pattern == "external-iam":
            return str(templates_dir / "stable-app.yaml")
        else:
            return str(templates_dir / "stable.yaml")


def _get_cfn_parameters(config: Any) -> Dict[str, str]:
    """Get CloudFormation parameters.

    Returns required parameters plus any optional parameters that were configured.

    Args:
        config: Deployment configuration

    Returns:
        Dictionary of CloudFormation parameters
    """
    # Required parameters
    params = {
        "AdminEmail": config.admin_email,
        "CertificateArnELB": config.certificate_arn,
        "QuiltWebHost": config.quilt_web_host,
        "PasswordAuth": "Enabled",  # Always enable for initial setup
    }

    # Optional authentication parameters (only if configured)
    # These would be added if the config had these fields
    # For now, we only include required parameters
    # Future: add google_client_secret, okta_client_secret, etc.

    return params


def _param_to_var_name(param_name: str) -> str:
    """Convert CloudFormation parameter name to Terraform variable name.

    Examples:
        AdminEmail -> admin_email
        CertificateArnELB -> certificate_arn_elb
        QuiltWebHost -> quilt_web_host

    Args:
        param_name: CloudFormation parameter name (PascalCase)

    Returns:
        Terraform variable name (snake_case)
    """
    # Insert underscore before uppercase letters (except first char)
    import re

    snake = re.sub("([a-z0-9])([A-Z])", r"\1_\2", param_name)
    # Convert to lowercase
    return snake.lower()


def _generate_main_tf(config: Dict[str, Any], pattern: str) -> str:
    """Generate main.tf content.

    Args:
        config: Infrastructure configuration
        pattern: Deployment pattern

    Returns:
        Terraform configuration as string
    """
    # Build parameters block
    params_lines = []
    for key, value in config["parameters"].items():
        # Only include non-empty values
        if value:
            if isinstance(value, str):
                params_lines.append(f"    {key} = var.{_param_to_var_name(key)}")
            else:
                params_lines.append(f"    {key} = var.{_param_to_var_name(key)}")
    params_block = "\n".join(params_lines)

    # Determine iam_template_url based on pattern
    if pattern == "external-iam":
        iam_template_url_line = f"  iam_template_url = var.iam_template_url"
    else:
        iam_template_url_line = f"  iam_template_url = null"

    # Generate main.tf
    return f"""# Generated by tf_deploy.py
# Deployment: {config["name"]}
# Pattern: {pattern}

terraform {{
  required_version = ">= 1.5.0"
  required_providers {{
    aws = {{
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }}
  }}
}}

provider "aws" {{
  region = var.aws_region
}}

module "quilt" {{
  source = "{config.get("module_path", "../../modules/quilt")}"

  # Stack name
  name = var.name

  # Template
  template_file = var.template_file

  # External IAM activation (null for inline, S3 URL for external)
{iam_template_url_line}

  # Network configuration
  create_new_vpc      = var.create_new_vpc
  vpc_id              = var.vpc_id
  intra_subnets       = var.intra_subnets
  private_subnets     = var.private_subnets
  public_subnets      = var.public_subnets
  user_security_group = var.user_security_group
  internal            = var.internal

  # Database configuration
  db_instance_class      = var.db_instance_class
  db_multi_az            = var.db_multi_az
  db_deletion_protection = var.db_deletion_protection

  # ElasticSearch configuration
  search_instance_type            = var.search_instance_type
  search_instance_count           = var.search_instance_count
  search_volume_size              = var.search_volume_size
  search_dedicated_master_enabled = var.search_dedicated_master_enabled
  search_zone_awareness_enabled   = var.search_zone_awareness_enabled

  # CloudFormation parameters
  parameters = {{
{params_block}
  }}
}}

# Outputs
output "stack_id" {{
  description = "CloudFormation stack ID"
  value       = module.quilt.stack.id
}}

output "stack_name" {{
  description = "CloudFormation stack name"
  value       = module.quilt.stack.stack_name
}}

output "admin_password" {{
  description = "Admin password"
  sensitive   = true
  value       = module.quilt.admin_password
}}

output "db_password" {{
  description = "Database password"
  sensitive   = true
  value       = module.quilt.db_password
}}

output "quilt_url" {{
  description = "Quilt catalog URL"
  value       = "https://${{var.quilt_web_host}}"
}}

# External IAM pattern outputs (only populated when iam_template_url is set)
output "iam_stack_name" {{
  description = "CloudFormation IAM stack name (null if inline IAM pattern)"
  value       = module.quilt.iam_stack_name
}}

output "iam_stack_id" {{
  description = "CloudFormation IAM stack ID (null if inline IAM pattern)"
  value       = module.quilt.iam_stack_id
}}
"""


def _generate_variables_tf(config: Any) -> str:
    """Generate variables.tf for all quilt module inputs.

    Args:
        config: Deployment configuration

    Returns:
        Variables.tf content as string
    """
    # Generate variable declarations for CloudFormation parameters
    cfn_params = _get_cfn_parameters(config)
    cfn_param_vars = []
    for param_name in cfn_params.keys():
        var_name = _param_to_var_name(param_name)
        cfn_param_vars.append(
            f"""variable "{var_name}" {{
  description = "CloudFormation parameter: {param_name}"
  type        = string
}}
"""
        )
    cfn_params_block = "\n".join(cfn_param_vars)

    return f"""# Terraform variables for quilt module inputs

variable "aws_region" {{
  description = "AWS region"
  type        = string
}}

variable "name" {{
  description = "Name for the deployment (stack name, VPC, DB, etc.)"
  type        = string
}}

variable "template_file" {{
  description = "Path to CloudFormation template file"
  type        = string
}}

variable "iam_template_url" {{
  description = "S3 URL to IAM CloudFormation template (null for inline IAM)"
  type        = string
  default     = null
}}

# Network configuration
variable "create_new_vpc" {{
  description = "Create a new VPC if true, otherwise use existing VPC"
  type        = bool
  default     = false
}}

variable "vpc_id" {{
  description = "Existing VPC ID"
  type        = string
}}

variable "intra_subnets" {{
  description = "Isolated subnet IDs (for DB and ElasticSearch)"
  type        = list(string)
}}

variable "private_subnets" {{
  description = "Private subnet IDs (for application)"
  type        = list(string)
}}

variable "public_subnets" {{
  description = "Public subnet IDs (for load balancer)"
  type        = list(string)
}}

variable "user_security_group" {{
  description = "Security group ID for user access"
  type        = string
}}

variable "internal" {{
  description = "If true create an internal ELB, else create an internet-facing ELB"
  type        = bool
  default     = false
}}

# Database configuration
variable "db_instance_class" {{
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}}

variable "db_multi_az" {{
  description = "Enable Multi-AZ for RDS"
  type        = bool
  default     = false
}}

variable "db_deletion_protection" {{
  description = "Enable deletion protection for RDS"
  type        = bool
  default     = false
}}

# ElasticSearch configuration
variable "search_instance_type" {{
  description = "ElasticSearch instance type"
  type        = string
  default     = "t3.small.elasticsearch"
}}

variable "search_instance_count" {{
  description = "Number of ElasticSearch instances"
  type        = number
  default     = 1
}}

variable "search_volume_size" {{
  description = "ElasticSearch volume size (GB)"
  type        = number
  default     = 10
}}

variable "search_dedicated_master_enabled" {{
  description = "Enable dedicated master nodes for ElasticSearch"
  type        = bool
  default     = false
}}

variable "search_zone_awareness_enabled" {{
  description = "Enable zone awareness for ElasticSearch"
  type        = bool
  default     = false
}}

# CloudFormation parameters
{cfn_params_block}

# Optional authentication secrets
variable "google_client_secret" {{
  description = "Google OAuth client secret (optional)"
  type        = string
  default     = ""
  sensitive   = true
}}

variable "okta_client_secret" {{
  description = "Okta OAuth client secret (optional)"
  type        = string
  default     = ""
  sensitive   = true
}}
"""


def _generate_tfvars_json(config: Any) -> str:
    """Generate terraform.tfvars.json with actual values.

    Args:
        config: Deployment configuration

    Returns:
        JSON string with tfvars
    """
    # Get infrastructure config which has all the values we need
    infra_config = _get_infrastructure_config(config, config.pattern)

    tfvars = {
        "aws_region": config.aws_region,
        "name": config.deployment_name,
        "template_file": infra_config["template_file"],
        # Network configuration
        "create_new_vpc": infra_config["create_new_vpc"],
        "vpc_id": infra_config["vpc_id"],
        "intra_subnets": infra_config["intra_subnets"],
        "private_subnets": infra_config["private_subnets"],
        "public_subnets": infra_config["public_subnets"],
        "user_security_group": infra_config["user_security_group"],
        "internal": False,  # Default to internet-facing ELB
        # Database configuration
        "db_instance_class": infra_config["db_instance_class"],
        "db_multi_az": infra_config["db_multi_az"],
        "db_deletion_protection": infra_config["db_deletion_protection"],
        # ElasticSearch configuration
        "search_instance_type": infra_config["search_instance_type"],
        "search_instance_count": infra_config["search_instance_count"],
        "search_volume_size": infra_config["search_volume_size"],
        "search_dedicated_master_enabled": infra_config["search_dedicated_master_enabled"],
        "search_zone_awareness_enabled": infra_config["search_zone_awareness_enabled"],
    }

    # Add CloudFormation parameters as individual variables
    cfn_params = infra_config["parameters"]
    for param_name, param_value in cfn_params.items():
        var_name = _param_to_var_name(param_name)
        tfvars[var_name] = param_value

    # Add IAM template URL for external-iam pattern
    if config.pattern == "external-iam":
        tfvars["iam_template_url"] = infra_config.get("iam_template_url")

    # Add secrets if configured
    if hasattr(config, "google_client_secret") and config.google_client_secret:
        tfvars["google_client_secret"] = config.google_client_secret

    if hasattr(config, "okta_client_secret") and config.okta_client_secret:
        tfvars["okta_client_secret"] = config.okta_client_secret

    return json.dumps(tfvars, indent=2)


def _generate_backend_tf(config: Any) -> str:
    """Generate backend.tf for state storage.

    Args:
        config: Deployment configuration

    Returns:
        Backend.tf content as string
    """
    return """# Terraform state backend configuration
# Using local state for testing
# For production, configure S3 backend

terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
"""


def format_dict(data: Dict[str, Any], indent: int = 2) -> str:
    """Format dictionary for pretty printing.

    Args:
        data: Dictionary to format
        indent: Indentation level

    Returns:
        Formatted string
    """
    return json.dumps(data, indent=indent, default=str)


def safe_get(data: Dict[str, Any], *keys: str, default: Any = None) -> Any:
    """Safely get nested dictionary value.

    Args:
        data: Dictionary to query
        *keys: Nested keys to traverse
        default: Default value if key not found

    Returns:
        Value at nested key or default
    """
    result = data
    for key in keys:
        if isinstance(result, dict):
            result = result.get(key)
            if result is None:
                return default
        else:
            return default
    return result

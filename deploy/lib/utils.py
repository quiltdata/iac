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
    output_dir: Path,
    config: Any,  # DeploymentConfig type
    pattern: str
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
    # Get template file path
    template_file = _get_template_file_path(config, pattern)

    infra_config = {
        "name": config.deployment_name,
        "template_file": template_file,

        # Network configuration
        "create_new_vpc": False,  # Use existing VPC from config
        "vpc_id": config.vpc_id,
        "intra_subnets": config.subnet_ids[:2],    # For DB & ES
        "private_subnets": config.subnet_ids[:2],  # For app
        "public_subnets": config.subnet_ids,       # For ALB
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
        infra_config["iam_template_url"] = config.iam_template_url or config._default_iam_template_url()
        infra_config["template_url"] = config.app_template_url or config._default_app_template_url()

    return infra_config


def _get_template_file_path(config: Any, pattern: str) -> str:
    """Get path to CloudFormation template file.

    For testing, use local template file.
    For production, use S3 URL.

    Args:
        config: Deployment configuration
        pattern: Deployment pattern

    Returns:
        Path to template file
    """
    templates_dir = Path(__file__).parent.parent.parent / "templates"

    if pattern == "external-iam":
        # Use app-only template
        return str(templates_dir / "quilt-app.yaml")
    else:
        # Use monolithic template
        return str(templates_dir / "quilt-cfn.yaml")


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
                params_lines.append(f'    {key} = "{value}"')
            else:
                params_lines.append(f'    {key} = {value}')
    params_block = "\n".join(params_lines)

    # Generate main.tf
    return f'''# Generated by tf_deploy.py
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
  name = "{config["name"]}"

  # Template
  template_file = "{config["template_file"]}"

  # Network configuration
  create_new_vpc = {str(config.get("create_new_vpc", False)).lower()}
  vpc_id         = "{config["vpc_id"]}"
  intra_subnets  = {json.dumps(config["intra_subnets"])}
  private_subnets = {json.dumps(config["private_subnets"])}
  public_subnets  = {json.dumps(config["public_subnets"])}
  user_security_group = "{config["user_security_group"]}"

  # Database configuration
  db_instance_class      = "{config["db_instance_class"]}"
  db_multi_az            = {str(config.get("db_multi_az", False)).lower()}
  db_deletion_protection = {str(config.get("db_deletion_protection", False)).lower()}

  # ElasticSearch configuration
  search_instance_type            = "{config["search_instance_type"]}"
  search_instance_count           = {config["search_instance_count"]}
  search_volume_size              = {config["search_volume_size"]}
  search_dedicated_master_enabled = {str(config.get("search_dedicated_master_enabled", False)).lower()}
  search_zone_awareness_enabled   = {str(config.get("search_zone_awareness_enabled", False)).lower()}

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
  value       = "https://{config["parameters"]["QuiltWebHost"]}"
}}
'''


def _generate_variables_tf(config: Any) -> str:
    """Generate variables.tf for optional secrets.

    Args:
        config: Deployment configuration

    Returns:
        Variables.tf content as string
    """
    return f'''# Variables for optional secrets

variable "aws_region" {{
  description = "AWS region"
  type        = string
  default     = "{config.aws_region}"
}}

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
'''


def _generate_tfvars_json(config: Any) -> str:
    """Generate terraform.tfvars.json with actual values.

    Args:
        config: Deployment configuration

    Returns:
        JSON string with tfvars
    """
    tfvars = {
        "aws_region": config.aws_region,
    }

    # Add secrets if configured
    # Check if config has these optional fields
    if hasattr(config, 'google_client_secret') and config.google_client_secret:
        tfvars["google_client_secret"] = config.google_client_secret

    if hasattr(config, 'okta_client_secret') and config.okta_client_secret:
        tfvars["okta_client_secret"] = config.okta_client_secret

    return json.dumps(tfvars, indent=2)


def _generate_backend_tf(config: Any) -> str:
    """Generate backend.tf for state storage.

    Args:
        config: Deployment configuration

    Returns:
        Backend.tf content as string
    """
    return '''# Terraform state backend configuration
# Using local state for testing
# For production, configure S3 backend

terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
'''


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

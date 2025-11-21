"""Utility functions for deployment script."""

import json
import logging
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
        output_dir: Output directory
        config: Deployment configuration
        pattern: Deployment pattern (external-iam or inline-iam)
    """
    output_dir.mkdir(parents=True, exist_ok=True)

    # Get template directory
    template_dir = Path(__file__).parent.parent / "templates"

    # Context for templates
    context = {
        "config": config,
        "pattern": pattern,
        "vars": config.to_terraform_vars(),
    }

    # Write variables file (JSON format for Terraform)
    vars_file = output_dir / "terraform.tfvars.json"
    with open(vars_file, "w") as f:
        json.dump(config.to_terraform_vars(), f, indent=2)

    logger.info(f"Wrote variables to {vars_file}")

    # Write backend configuration
    backend_template = template_dir / "backend.tf.j2"
    if backend_template.exists():
        backend_content = render_template_file(backend_template, context)
        backend_file = output_dir / "backend.tf"
        with open(backend_file, "w") as f:
            f.write(backend_content)
        logger.info(f"Wrote backend configuration to {backend_file}")

    # Write main Terraform configuration based on pattern
    if pattern == "external-iam":
        main_template = template_dir / "external-iam.tf.j2"
    else:
        main_template = template_dir / "inline-iam.tf.j2"

    if main_template.exists():
        main_content = render_template_file(main_template, context)
        main_file = output_dir / "main.tf"
        with open(main_file, "w") as f:
            f.write(main_content)
        logger.info(f"Wrote main configuration to {main_file}")

    # Write variables definition
    variables_template = template_dir / "variables.tf.j2"
    if variables_template.exists():
        variables_content = render_template_file(variables_template, context)
        variables_file = output_dir / "variables.tf"
        with open(variables_file, "w") as f:
            f.write(variables_content)
        logger.info(f"Wrote variables definition to {variables_file}")


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

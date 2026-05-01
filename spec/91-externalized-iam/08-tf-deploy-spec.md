# Deployment Script Specification

**Issue**: [#91 - externalized IAM](https://github.com/quiltdata/quilt-infrastructure/issues/91)

**Date**: 2025-11-20

**Branch**: 91-externalized-iam

**References**:

- [07-testing-guide.md](07-testing-guide.md) - Testing procedures
- [config.json](../../test/fixtures/config.json) - Environment configuration
- [06-implementation-summary.md](06-implementation-summary.md) - Implementation details

## Executive Summary

This specification defines a Python deployment script (`deploy/tf_deploy.py`) that reads environment configuration from `test/fixtures/config.json` and orchestrates Terraform stack deployments for the externalized IAM feature. The script provides a unified interface to create, deploy, and validate both IAM and application infrastructure stacks.

## Design Philosophy

**Key Principles**:

1. **Configuration-Driven**: All deployment parameters sourced from config.json
2. **Validation-First**: Validate before deploy to catch errors early
3. **Idempotent**: Safe to run multiple times
4. **Observable**: Clear logging and status reporting
5. **Composable**: Can deploy IAM-only, app-only, or both
6. **Testable**: Supports dry-run and validation modes

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  tf_deploy.py                        │
│                                                         │
│  ┌───────────────┐  ┌────────────────┐  ┌───────────┐ │
│  │ Config Reader │→ │ Stack Manager  │→ │ Validator │ │
│  └───────────────┘  └────────────────┘  └───────────┘ │
│         ↓                   ↓                   ↓      │
│  ┌───────────────────────────────────────────────────┐ │
│  │           Terraform Orchestrator                  │ │
│  │  - init   - plan   - apply   - output   - destroy│ │
│  └───────────────────────────────────────────────────┘ │
│                            ↓                           │
└────────────────────────────┼────────────────────────────┘
                             ↓
              ┌──────────────┴───────────────┐
              ↓                              ↓
     ┌────────────────┐           ┌──────────────────┐
     │  IAM Module    │           │  Quilt Module    │
     │  (modules/iam) │           │  (modules/quilt) │
     └────────────────┘           └──────────────────┘
              ↓                              ↓
     ┌────────────────┐           ┌──────────────────┐
     │ IAM CF Stack   │           │  App CF Stack    │
     └────────────────┘           └──────────────────┘
```

## Requirements

### Functional Requirements

**FR1: Configuration Management**

- Read and parse `test/fixtures/config.json`
- Extract VPC, subnet, security group, certificate, and Route53 information
- Generate Terraform variables from config data
- Support environment-specific overrides

**FR2: Stack Creation**

- Generate Terraform configuration files dynamically
- Support both inline and external IAM patterns
- Create necessary directory structure
- Initialize Terraform backend configuration

**FR3: Stack Deployment**

- Execute Terraform workflow: init → plan → apply
- Handle deployment errors gracefully
- Support partial deployments (IAM-only, app-only)
- Capture and display Terraform outputs

**FR4: Stack Validation**

- Validate Terraform configuration syntax
- Verify CloudFormation stack status
- Check resource creation (IAM roles, policies, application resources)
- Validate connectivity and health endpoints
- Compare actual state with expected state

**FR5: Operations Support**

- Support dry-run mode (plan only)
- Enable verbose logging
- Generate deployment reports
- Support stack updates and destroys

### Non-Functional Requirements

**NFR1: Usability**

- Simple command-line interface
- Clear error messages
- Progress indicators for long operations
- Helpful usage documentation

**NFR2: Reliability**

- Validate inputs before deployment
- Handle AWS API rate limits
- Support retries for transient failures
- Clean rollback on critical errors

**NFR3: Performance**

- Parallel resource queries where possible
- Efficient config parsing
- Minimal overhead over native Terraform

**NFR4: Maintainability**

- Well-documented code
- Modular architecture
- Type hints throughout
- Comprehensive logging

## Configuration Schema

### Input: test/fixtures/config.json

The script reads the existing config.json fixture and extracts:

```python
{
    "version": "1.0",
    "account_id": "712023778557",
    "region": "us-east-1",
    "environment": "iac",
    "domain": "quilttest.com",
    "email": "dev@quiltdata.io",
    "detected": {
        "vpcs": [...],           # Select non-default VPC
        "subnets": [...],        # Select public subnets
        "security_groups": [...],# Select appropriate SGs
        "certificates": [...],   # Select matching domain cert
        "route53_zones": [...]   # Select matching domain zone
    }
}
```

### Output: Deployment Configuration

```python
{
    "deployment_name": "quilt-iac-test",
    "aws_region": "us-east-1",
    "aws_account_id": "712023778557",
    "vpc_id": "vpc-010008ef3cce35c0c",  # quilt-staging VPC
    "subnet_ids": [
        "subnet-0f667dc82fa781381",     # public-us-east-1a
        "subnet-0e5edea8f1785e300"      # public-us-east-1b
    ],
    "certificate_arn": "arn:aws:acm:...:certificate/2b16c20f-...",
    "route53_zone_id": "Z050530821I8SLJEKKYY6",
    "domain_name": "quilttest.com",
    "admin_email": "dev@quiltdata.io",
    "pattern": "external-iam",  # or "inline-iam"
    "iam_template_url": "https://...",  # if external pattern
    "app_template_url": "https://..."
}
```

## Script Interface

### Command-Line Interface

```bash
# Basic usage
./deploy/tf_deploy.py --config test/fixtures/config.json --action deploy

# Available commands
./deploy/tf_deploy.py create    # Create stack configuration
./deploy/tf_deploy.py deploy    # Deploy stack (create + apply)
./deploy/tf_deploy.py validate  # Validate deployed stack
./deploy/tf_deploy.py destroy   # Destroy stack
./deploy/tf_deploy.py status    # Show stack status
./deploy/tf_deploy.py outputs   # Show stack outputs

# Options
--config PATH         # Config file path (default: test/fixtures/config.json)
--pattern TYPE        # Pattern: external-iam or inline-iam (default: external-iam)
--name NAME           # Deployment name (default: from config)
--dry-run             # Show plan without applying
--auto-approve        # Skip confirmation prompts
--verbose             # Enable verbose logging
--output-dir PATH     # Output directory (default: .deploy)
--stack-type TYPE     # Stack type: iam, app, or both (default: both)

# Examples
./deploy/tf_deploy.py deploy --config test/fixtures/config.json --pattern external-iam
./deploy/tf_deploy.py deploy --pattern inline-iam --dry-run
./deploy/tf_deploy.py validate --name quilt-iac-test
./deploy/tf_deploy.py destroy --auto-approve
```

### Exit Codes

```python
EXIT_SUCCESS = 0           # Successful execution
EXIT_CONFIG_ERROR = 1      # Configuration error
EXIT_VALIDATION_ERROR = 2  # Validation failure
EXIT_DEPLOYMENT_ERROR = 3  # Deployment failure
EXIT_AWS_ERROR = 4         # AWS API error
EXIT_TERRAFORM_ERROR = 5   # Terraform execution error
EXIT_USER_CANCELLED = 6    # User cancelled operation
```

## Implementation Details

### File Structure

```
deploy/
├── tf_deploy.py          # Main script
├── lib/
│   ├── __init__.py
│   ├── config.py            # Configuration management
│   ├── terraform.py         # Terraform wrapper
│   ├── validator.py         # Validation logic
│   ├── aws_client.py        # AWS API wrapper
│   └── utils.py             # Utilities
├── templates/
│   ├── backend.tf.j2        # Terraform backend template
│   ├── external-iam.tf.j2   # External IAM pattern template
│   ├── inline-iam.tf.j2     # Inline IAM pattern template
│   └── variables.tf.j2      # Variables template
└── pyproject.toml           # UV project configuration
```

### Core Modules

#### Module 1: Configuration Management (lib/config.py)

```python
"""Configuration management for deployment script."""

from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional
import json


@dataclass
class DeploymentConfig:
    """Deployment configuration."""

    # Identity
    deployment_name: str
    aws_region: str
    aws_account_id: str
    environment: str

    # Network
    vpc_id: str
    subnet_ids: List[str]
    security_group_ids: List[str]

    # DNS/TLS
    certificate_arn: str
    route53_zone_id: str
    domain_name: str
    quilt_web_host: str

    # Configuration
    admin_email: str
    pattern: str  # "external-iam" or "inline-iam"

    # Templates
    iam_template_url: Optional[str] = None
    app_template_url: Optional[str] = None

    # Options
    db_instance_class: str = "db.t3.micro"
    search_instance_type: str = "t3.small.elasticsearch"
    search_volume_size: int = 10

    @classmethod
    def from_config_file(cls, config_path: Path, **overrides) -> "DeploymentConfig":
        """Load configuration from config.json."""
        with open(config_path) as f:
            config = json.load(f)

        # Extract and validate required fields
        deployment_name = overrides.get("name", f"quilt-{config['environment']}")

        # Select appropriate VPC (prefer quilt-staging)
        vpc = cls._select_vpc(config["detected"]["vpcs"])

        # Select public subnets in that VPC
        subnets = cls._select_subnets(
            config["detected"]["subnets"],
            vpc["vpc_id"]
        )

        # Select security groups in that VPC
        security_groups = cls._select_security_groups(
            config["detected"]["security_groups"],
            vpc["vpc_id"]
        )

        # Select certificate matching domain
        certificate = cls._select_certificate(
            config["detected"]["certificates"],
            config["domain"]
        )

        # Select Route53 zone matching domain
        zone = cls._select_route53_zone(
            config["detected"]["route53_zones"],
            config["domain"]
        )

        return cls(
            deployment_name=deployment_name,
            aws_region=config["region"],
            aws_account_id=config["account_id"],
            environment=config["environment"],
            vpc_id=vpc["vpc_id"],
            subnet_ids=[s["subnet_id"] for s in subnets],
            security_group_ids=[sg["security_group_id"] for sg in security_groups],
            certificate_arn=certificate["arn"],
            route53_zone_id=zone["zone_id"],
            domain_name=config["domain"],
            quilt_web_host=f"{deployment_name}.{config['domain']}",
            admin_email=config["email"],
            pattern=overrides.get("pattern", "external-iam"),
            **{k: v for k, v in overrides.items() if k not in ["name", "pattern"]}
        )

    @staticmethod
    def _select_vpc(vpcs: List[Dict]) -> Dict:
        """Select VPC (prefer quilt-staging, then first non-default)."""
        # Prefer quilt-staging VPC
        for vpc in vpcs:
            if vpc["name"] == "quilt-staging":
                return vpc

        # Fall back to first non-default VPC
        for vpc in vpcs:
            if not vpc["is_default"]:
                return vpc

        raise ValueError("No suitable VPC found")

    @staticmethod
    def _select_subnets(subnets: List[Dict], vpc_id: str) -> List[Dict]:
        """Select public subnets in the VPC (need at least 2)."""
        public_subnets = [
            s for s in subnets
            if s["vpc_id"] == vpc_id and s["classification"] == "public"
        ]

        if len(public_subnets) < 2:
            raise ValueError(f"Need at least 2 public subnets, found {len(public_subnets)}")

        return public_subnets[:2]  # Return first 2

    @staticmethod
    def _select_security_groups(security_groups: List[Dict], vpc_id: str) -> List[Dict]:
        """Select security groups in the VPC."""
        sgs = [
            sg for sg in security_groups
            if sg["vpc_id"] == vpc_id and sg.get("in_use", False)
        ]

        if not sgs:
            raise ValueError(f"No suitable security groups found in VPC {vpc_id}")

        return sgs[:3]  # Return up to 3

    @staticmethod
    def _select_certificate(certificates: List[Dict], domain: str) -> Dict:
        """Select certificate matching domain."""
        for cert in certificates:
            if cert["domain_name"] == f"*.{domain}":
                if cert["status"] == "ISSUED":
                    return cert

        raise ValueError(f"No valid certificate found for domain {domain}")

    @staticmethod
    def _select_route53_zone(zones: List[Dict], domain: str) -> Dict:
        """Select Route53 zone matching domain."""
        for zone in zones:
            if zone["domain_name"] == f"{domain}.":
                if not zone["private"]:
                    return zone

        raise ValueError(f"No Route53 zone found for domain {domain}")

    def to_terraform_vars(self) -> Dict[str, any]:
        """Convert to Terraform variables."""
        vars_dict = {
            "name": self.deployment_name,
            "aws_region": self.aws_region,
            "aws_account_id": self.aws_account_id,
            "vpc_id": self.vpc_id,
            "subnet_ids": self.subnet_ids,
            "certificate_arn": self.certificate_arn,
            "route53_zone_id": self.route53_zone_id,
            "quilt_web_host": self.quilt_web_host,
            "admin_email": self.admin_email,
            "db_instance_class": self.db_instance_class,
            "search_instance_type": self.search_instance_type,
            "search_volume_size": self.search_volume_size,
        }

        # Add pattern-specific vars
        if self.pattern == "external-iam":
            if not self.iam_template_url:
                raise ValueError("iam_template_url required for external-iam pattern")
            vars_dict["iam_template_url"] = self.iam_template_url
            vars_dict["template_url"] = self.app_template_url or self._default_app_template_url()
        else:
            vars_dict["template_url"] = self._default_monolithic_template_url()

        return vars_dict

    def _default_app_template_url(self) -> str:
        """Default application template URL."""
        return (
            f"https://quilt-templates-{self.environment}-{self.aws_account_id}"
            f".s3.{self.aws_region}.amazonaws.com/quilt-app.yaml"
        )

    def _default_monolithic_template_url(self) -> str:
        """Default monolithic template URL."""
        return (
            f"https://quilt-templates-{self.environment}-{self.aws_account_id}"
            f".s3.{self.aws_region}.amazonaws.com/quilt-monolithic.yaml"
        )
```

#### Module 2: Terraform Orchestrator (lib/terraform.py)

```python
"""Terraform orchestration."""

import json
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional
import logging

logger = logging.getLogger(__name__)


@dataclass
class TerraformResult:
    """Result of a Terraform operation."""

    success: bool
    command: str
    stdout: str
    stderr: str
    return_code: int

    @property
    def output(self) -> str:
        """Combined output."""
        return self.stdout + self.stderr


class TerraformOrchestrator:
    """Terraform command orchestrator."""

    def __init__(self, working_dir: Path, terraform_bin: str = "terraform"):
        """Initialize orchestrator.

        Args:
            working_dir: Working directory for Terraform
            terraform_bin: Path to terraform binary
        """
        self.working_dir = working_dir
        self.terraform_bin = terraform_bin
        self.working_dir.mkdir(parents=True, exist_ok=True)

    def init(self, backend_config: Optional[Dict[str, str]] = None) -> TerraformResult:
        """Run terraform init.

        Args:
            backend_config: Backend configuration overrides

        Returns:
            TerraformResult
        """
        cmd = [self.terraform_bin, "init", "-upgrade"]

        if backend_config:
            for key, value in backend_config.items():
                cmd.extend(["-backend-config", f"{key}={value}"])

        return self._run_command(cmd)

    def validate(self) -> TerraformResult:
        """Run terraform validate.

        Returns:
            TerraformResult
        """
        return self._run_command([self.terraform_bin, "validate"])

    def plan(self, var_file: Optional[Path] = None, out_file: Optional[Path] = None) -> TerraformResult:
        """Run terraform plan.

        Args:
            var_file: Path to variables file
            out_file: Path to save plan

        Returns:
            TerraformResult
        """
        cmd = [self.terraform_bin, "plan"]

        if var_file:
            cmd.extend(["-var-file", str(var_file)])

        if out_file:
            cmd.extend(["-out", str(out_file)])

        return self._run_command(cmd)

    def apply(self, plan_file: Optional[Path] = None, var_file: Optional[Path] = None,
              auto_approve: bool = False) -> TerraformResult:
        """Run terraform apply.

        Args:
            plan_file: Path to plan file
            var_file: Path to variables file
            auto_approve: Auto-approve changes

        Returns:
            TerraformResult
        """
        cmd = [self.terraform_bin, "apply"]

        if plan_file:
            cmd.append(str(plan_file))
        elif var_file:
            cmd.extend(["-var-file", str(var_file)])

        if auto_approve:
            cmd.append("-auto-approve")

        return self._run_command(cmd)

    def destroy(self, var_file: Optional[Path] = None, auto_approve: bool = False) -> TerraformResult:
        """Run terraform destroy.

        Args:
            var_file: Path to variables file
            auto_approve: Auto-approve destruction

        Returns:
            TerraformResult
        """
        cmd = [self.terraform_bin, "destroy"]

        if var_file:
            cmd.extend(["-var-file", str(var_file)])

        if auto_approve:
            cmd.append("-auto-approve")

        return self._run_command(cmd)

    def output(self, name: Optional[str] = None, json_format: bool = True) -> TerraformResult:
        """Run terraform output.

        Args:
            name: Specific output name (if None, all outputs)
            json_format: Output as JSON

        Returns:
            TerraformResult
        """
        cmd = [self.terraform_bin, "output"]

        if json_format:
            cmd.append("-json")

        if name:
            cmd.append(name)

        return self._run_command(cmd)

    def get_outputs(self) -> Dict[str, any]:
        """Get all outputs as dict.

        Returns:
            Dict of outputs
        """
        result = self.output(json_format=True)
        if not result.success:
            return {}

        try:
            outputs = json.loads(result.stdout)
            return {k: v.get("value") for k, v in outputs.items()}
        except json.JSONDecodeError:
            logger.error("Failed to parse terraform output JSON")
            return {}

    def _run_command(self, cmd: List[str]) -> TerraformResult:
        """Run terraform command.

        Args:
            cmd: Command and arguments

        Returns:
            TerraformResult
        """
        logger.info(f"Running: {' '.join(cmd)}")

        try:
            result = subprocess.run(
                cmd,
                cwd=self.working_dir,
                capture_output=True,
                text=True,
                timeout=3600  # 1 hour timeout
            )

            return TerraformResult(
                success=result.returncode == 0,
                command=" ".join(cmd),
                stdout=result.stdout,
                stderr=result.stderr,
                return_code=result.returncode
            )

        except subprocess.TimeoutExpired:
            logger.error("Terraform command timed out")
            return TerraformResult(
                success=False,
                command=" ".join(cmd),
                stdout="",
                stderr="Command timed out after 1 hour",
                return_code=124
            )

        except Exception as e:
            logger.error(f"Failed to run terraform command: {e}")
            return TerraformResult(
                success=False,
                command=" ".join(cmd),
                stdout="",
                stderr=str(e),
                return_code=1
            )
```

#### Module 3: Validator (lib/validator.py)

```python
"""Stack validation."""

import logging
from dataclasses import dataclass
from typing import Dict, List, Optional
import boto3
import requests

logger = logging.getLogger(__name__)


@dataclass
class ValidationResult:
    """Validation result."""

    passed: bool
    test_name: str
    message: str
    details: Optional[Dict] = None


class StackValidator:
    """Stack validator."""

    def __init__(self, aws_region: str):
        """Initialize validator.

        Args:
            aws_region: AWS region
        """
        self.aws_region = aws_region
        self.cf_client = boto3.client("cloudformation", region_name=aws_region)
        self.iam_client = boto3.client("iam", region_name=aws_region)
        self.elbv2_client = boto3.client("elbv2", region_name=aws_region)

    def validate_stack(self, stack_name: str, expected_resources: Optional[Dict] = None) -> List[ValidationResult]:
        """Validate CloudFormation stack.

        Args:
            stack_name: Stack name
            expected_resources: Expected resource counts

        Returns:
            List of ValidationResult
        """
        results = []

        # Test 1: Stack exists
        results.append(self._validate_stack_exists(stack_name))

        # Test 2: Stack status
        results.append(self._validate_stack_status(stack_name))

        # Test 3: Resources created
        results.append(self._validate_resources(stack_name, expected_resources))

        return results

    def validate_iam_stack(self, stack_name: str) -> List[ValidationResult]:
        """Validate IAM stack specifically.

        Args:
            stack_name: IAM stack name

        Returns:
            List of ValidationResult
        """
        results = []

        # Validate stack
        results.extend(self.validate_stack(
            stack_name,
            expected_resources={"AWS::IAM::Role": 24, "AWS::IAM::ManagedPolicy": 8}
        ))

        # Test: All outputs are valid ARNs
        results.append(self._validate_iam_outputs(stack_name))

        # Test: IAM resources exist in AWS
        results.append(self._validate_iam_resources_exist(stack_name))

        return results

    def validate_app_stack(self, stack_name: str, iam_stack_name: Optional[str] = None) -> List[ValidationResult]:
        """Validate application stack.

        Args:
            stack_name: Application stack name
            iam_stack_name: IAM stack name (if external pattern)

        Returns:
            List of ValidationResult
        """
        results = []

        # Validate stack
        results.extend(self.validate_stack(stack_name))

        # If external IAM, validate parameters
        if iam_stack_name:
            results.append(self._validate_iam_parameters(stack_name, iam_stack_name))

        # Validate application is accessible
        results.append(self._validate_application_accessible(stack_name))

        return results

    def _validate_stack_exists(self, stack_name: str) -> ValidationResult:
        """Validate stack exists."""
        try:
            self.cf_client.describe_stacks(StackName=stack_name)
            return ValidationResult(
                passed=True,
                test_name="stack_exists",
                message=f"Stack {stack_name} exists"
            )
        except self.cf_client.exceptions.ClientError:
            return ValidationResult(
                passed=False,
                test_name="stack_exists",
                message=f"Stack {stack_name} does not exist"
            )

    def _validate_stack_status(self, stack_name: str) -> ValidationResult:
        """Validate stack is in successful state."""
        try:
            response = self.cf_client.describe_stacks(StackName=stack_name)
            stack = response["Stacks"][0]
            status = stack["StackStatus"]

            success_statuses = ["CREATE_COMPLETE", "UPDATE_COMPLETE"]
            passed = status in success_statuses

            return ValidationResult(
                passed=passed,
                test_name="stack_status",
                message=f"Stack status: {status}",
                details={"status": status}
            )
        except Exception as e:
            return ValidationResult(
                passed=False,
                test_name="stack_status",
                message=f"Failed to get stack status: {e}"
            )

    def _validate_resources(self, stack_name: str, expected: Optional[Dict] = None) -> ValidationResult:
        """Validate resources created."""
        try:
            response = self.cf_client.describe_stack_resources(StackName=stack_name)
            resources = response["StackResources"]

            # Count by type
            resource_counts = {}
            for resource in resources:
                rtype = resource["ResourceType"]
                resource_counts[rtype] = resource_counts.get(rtype, 0) + 1

            # Validate expected counts
            if expected:
                for rtype, expected_count in expected.items():
                    actual_count = resource_counts.get(rtype, 0)
                    if actual_count != expected_count:
                        return ValidationResult(
                            passed=False,
                            test_name="resource_counts",
                            message=f"Expected {expected_count} {rtype}, found {actual_count}",
                            details=resource_counts
                        )

            return ValidationResult(
                passed=True,
                test_name="resource_counts",
                message=f"Found {len(resources)} resources",
                details=resource_counts
            )

        except Exception as e:
            return ValidationResult(
                passed=False,
                test_name="resource_counts",
                message=f"Failed to validate resources: {e}"
            )

    def _validate_iam_outputs(self, stack_name: str) -> ValidationResult:
        """Validate IAM outputs are valid ARNs."""
        try:
            response = self.cf_client.describe_stacks(StackName=stack_name)
            outputs = response["Stacks"][0].get("Outputs", [])

            # All outputs should be ARNs
            invalid_arns = []
            for output in outputs:
                value = output["OutputValue"]
                if not value.startswith("arn:aws:iam::"):
                    invalid_arns.append(output["OutputKey"])

            if invalid_arns:
                return ValidationResult(
                    passed=False,
                    test_name="iam_output_arns",
                    message=f"Invalid ARNs in outputs: {invalid_arns}",
                    details={"invalid": invalid_arns}
                )

            return ValidationResult(
                passed=True,
                test_name="iam_output_arns",
                message=f"All {len(outputs)} outputs are valid ARNs"
            )

        except Exception as e:
            return ValidationResult(
                passed=False,
                test_name="iam_output_arns",
                message=f"Failed to validate IAM outputs: {e}"
            )

    def _validate_iam_resources_exist(self, stack_name: str) -> ValidationResult:
        """Validate IAM resources exist in AWS."""
        try:
            # List roles with stack name prefix
            response = self.iam_client.list_roles()
            roles = [r for r in response["Roles"] if r["RoleName"].startswith(stack_name)]

            if len(roles) < 20:  # Expect at least 20 roles
                return ValidationResult(
                    passed=False,
                    test_name="iam_resources_exist",
                    message=f"Expected at least 20 IAM roles, found {len(roles)}",
                    details={"role_count": len(roles)}
                )

            return ValidationResult(
                passed=True,
                test_name="iam_resources_exist",
                message=f"Found {len(roles)} IAM roles"
            )

        except Exception as e:
            return ValidationResult(
                passed=False,
                test_name="iam_resources_exist",
                message=f"Failed to validate IAM resources: {e}"
            )

    def _validate_iam_parameters(self, app_stack_name: str, iam_stack_name: str) -> ValidationResult:
        """Validate application stack has IAM parameters."""
        try:
            response = self.cf_client.describe_stacks(StackName=app_stack_name)
            parameters = response["Stacks"][0].get("Parameters", [])

            # Count IAM parameters (contain "Role" or "Policy")
            iam_params = [p for p in parameters if "Role" in p["ParameterKey"] or "Policy" in p["ParameterKey"]]

            if len(iam_params) < 30:  # Expect at least 30 IAM parameters
                return ValidationResult(
                    passed=False,
                    test_name="iam_parameters",
                    message=f"Expected at least 30 IAM parameters, found {len(iam_params)}",
                    details={"iam_param_count": len(iam_params)}
                )

            return ValidationResult(
                passed=True,
                test_name="iam_parameters",
                message=f"Found {len(iam_params)} IAM parameters"
            )

        except Exception as e:
            return ValidationResult(
                passed=False,
                test_name="iam_parameters",
                message=f"Failed to validate IAM parameters: {e}"
            )

    def _validate_application_accessible(self, stack_name: str) -> ValidationResult:
        """Validate application is accessible."""
        try:
            # Get ALB DNS name
            response = self.elbv2_client.describe_load_balancers()
            albs = [alb for alb in response["LoadBalancers"] if stack_name in alb["LoadBalancerName"]]

            if not albs:
                return ValidationResult(
                    passed=False,
                    test_name="application_accessible",
                    message=f"No load balancer found for stack {stack_name}"
                )

            alb_dns = albs[0]["DNSName"]
            url = f"http://{alb_dns}/health"

            # Try to access health endpoint
            response = requests.get(url, timeout=10, verify=False)

            if response.status_code == 200:
                return ValidationResult(
                    passed=True,
                    test_name="application_accessible",
                    message=f"Application accessible at {url}"
                )
            else:
                return ValidationResult(
                    passed=False,
                    test_name="application_accessible",
                    message=f"Application returned status {response.status_code}",
                    details={"status_code": response.status_code}
                )

        except Exception as e:
            return ValidationResult(
                passed=False,
                test_name="application_accessible",
                message=f"Failed to access application: {e}"
            )
```

#### Module 4: Main Script (tf_deploy.py)

```python
#!/usr/bin/env python3
"""
Deployment script for Quilt infrastructure with externalized IAM.

This script reads configuration from test/fixtures/config.json and orchestrates
Terraform deployments for both IAM and application stacks.

Usage:
    ./deploy/tf_deploy.py deploy --config test/fixtures/config.json
    ./deploy/tf_deploy.py validate --name quilt-iac-test
    ./deploy/tf_deploy.py destroy --auto-approve
"""

import argparse
import logging
import sys
from pathlib import Path
from typing import Optional

from lib.config import DeploymentConfig
from lib.terraform import TerraformOrchestrator
from lib.validator import StackValidator
from lib.utils import setup_logging, write_terraform_files, confirm_action


# Exit codes
EXIT_SUCCESS = 0
EXIT_CONFIG_ERROR = 1
EXIT_VALIDATION_ERROR = 2
EXIT_DEPLOYMENT_ERROR = 3
EXIT_AWS_ERROR = 4
EXIT_TERRAFORM_ERROR = 5
EXIT_USER_CANCELLED = 6


class StackDeployer:
    """Stack deployment orchestrator."""

    def __init__(self, config: DeploymentConfig, output_dir: Path, verbose: bool = False):
        """Initialize deployer.

        Args:
            config: Deployment configuration
            output_dir: Output directory for Terraform files
            verbose: Enable verbose logging
        """
        self.config = config
        self.output_dir = output_dir
        self.verbose = verbose
        self.logger = logging.getLogger(__name__)

        # Initialize components
        self.terraform = TerraformOrchestrator(output_dir)
        self.validator = StackValidator(config.aws_region)

    def create(self) -> int:
        """Create stack configuration files.

        Returns:
            Exit code
        """
        self.logger.info("Creating stack configuration...")

        try:
            # Write Terraform files
            write_terraform_files(
                output_dir=self.output_dir,
                config=self.config,
                pattern=self.config.pattern
            )

            self.logger.info(f"Stack configuration created in {self.output_dir}")
            return EXIT_SUCCESS

        except Exception as e:
            self.logger.error(f"Failed to create configuration: {e}")
            return EXIT_CONFIG_ERROR

    def deploy(self, dry_run: bool = False, auto_approve: bool = False,
               stack_type: str = "both") -> int:
        """Deploy stack.

        Args:
            dry_run: Plan only, don't apply
            auto_approve: Skip confirmation
            stack_type: "iam", "app", or "both"

        Returns:
            Exit code
        """
        self.logger.info(f"Deploying stack (pattern: {self.config.pattern}, type: {stack_type})...")

        # Step 1: Create configuration
        result = self.create()
        if result != EXIT_SUCCESS:
            return result

        # Step 2: Initialize Terraform
        self.logger.info("Initializing Terraform...")
        tf_result = self.terraform.init()
        if not tf_result.success:
            self.logger.error("Terraform init failed")
            self.logger.error(tf_result.stderr)
            return EXIT_TERRAFORM_ERROR

        # Step 3: Validate
        self.logger.info("Validating Terraform configuration...")
        tf_result = self.terraform.validate()
        if not tf_result.success:
            self.logger.error("Terraform validate failed")
            self.logger.error(tf_result.stderr)
            return EXIT_VALIDATION_ERROR

        # Step 4: Plan
        self.logger.info("Planning deployment...")
        plan_file = self.output_dir / "terraform.tfplan"
        var_file = self.output_dir / "terraform.tfvars.json"

        tf_result = self.terraform.plan(var_file=var_file, out_file=plan_file)
        if not tf_result.success:
            self.logger.error("Terraform plan failed")
            self.logger.error(tf_result.stderr)
            return EXIT_TERRAFORM_ERROR

        # Print plan
        print("\n" + "="*80)
        print("DEPLOYMENT PLAN")
        print("="*80)
        print(tf_result.stdout)
        print("="*80 + "\n")

        if dry_run:
            self.logger.info("Dry run complete")
            return EXIT_SUCCESS

        # Step 5: Confirm
        if not auto_approve:
            if not confirm_action("Apply this plan?"):
                self.logger.info("Deployment cancelled by user")
                return EXIT_USER_CANCELLED

        # Step 6: Apply
        self.logger.info("Applying deployment...")
        tf_result = self.terraform.apply(plan_file=plan_file, auto_approve=True)
        if not tf_result.success:
            self.logger.error("Terraform apply failed")
            self.logger.error(tf_result.stderr)
            return EXIT_DEPLOYMENT_ERROR

        # Step 7: Show outputs
        self.logger.info("Deployment complete!")
        self._show_outputs()

        return EXIT_SUCCESS

    def validate(self) -> int:
        """Validate deployed stack.

        Returns:
            Exit code
        """
        self.logger.info("Validating deployed stack...")

        try:
            # Get outputs to find stack names
            outputs = self.terraform.get_outputs()

            all_passed = True

            # Validate IAM stack if external pattern
            if self.config.pattern == "external-iam" and "iam_stack_name" in outputs:
                iam_stack = outputs["iam_stack_name"]
                self.logger.info(f"Validating IAM stack: {iam_stack}")

                results = self.validator.validate_iam_stack(iam_stack)
                self._print_validation_results(results)

                if not all(r.passed for r in results):
                    all_passed = False

            # Validate application stack
            if "app_stack_name" in outputs:
                app_stack = outputs["app_stack_name"]
                iam_stack = outputs.get("iam_stack_name")

                self.logger.info(f"Validating application stack: {app_stack}")

                results = self.validator.validate_app_stack(app_stack, iam_stack)
                self._print_validation_results(results)

                if not all(r.passed for r in results):
                    all_passed = False

            if all_passed:
                self.logger.info("✓ All validation tests passed")
                return EXIT_SUCCESS
            else:
                self.logger.error("✗ Some validation tests failed")
                return EXIT_VALIDATION_ERROR

        except Exception as e:
            self.logger.error(f"Validation failed: {e}")
            return EXIT_VALIDATION_ERROR

    def destroy(self, auto_approve: bool = False) -> int:
        """Destroy stack.

        Args:
            auto_approve: Skip confirmation

        Returns:
            Exit code
        """
        self.logger.warning("Destroying stack...")

        # Confirm
        if not auto_approve:
            if not confirm_action(f"Destroy stack {self.config.deployment_name}? This cannot be undone!"):
                self.logger.info("Destruction cancelled by user")
                return EXIT_USER_CANCELLED

        # Destroy
        var_file = self.output_dir / "terraform.tfvars.json"
        tf_result = self.terraform.destroy(var_file=var_file, auto_approve=True)

        if not tf_result.success:
            self.logger.error("Terraform destroy failed")
            self.logger.error(tf_result.stderr)
            return EXIT_TERRAFORM_ERROR

        self.logger.info("Stack destroyed")
        return EXIT_SUCCESS

    def status(self) -> int:
        """Show stack status.

        Returns:
            Exit code
        """
        self.logger.info("Getting stack status...")

        try:
            outputs = self.terraform.get_outputs()

            print("\n" + "="*80)
            print("STACK STATUS")
            print("="*80)
            print(f"Deployment: {self.config.deployment_name}")
            print(f"Pattern: {self.config.pattern}")
            print(f"Region: {self.config.aws_region}")
            print()

            if "iam_stack_name" in outputs:
                print(f"IAM Stack: {outputs['iam_stack_name']}")
                print(f"IAM Stack ID: {outputs.get('iam_stack_id', 'N/A')}")
                print()

            if "app_stack_name" in outputs:
                print(f"Application Stack: {outputs['app_stack_name']}")
                print(f"Application Stack ID: {outputs.get('app_stack_id', 'N/A')}")
                print()

            if "quilt_url" in outputs:
                print(f"Quilt URL: {outputs['quilt_url']}")

            print("="*80 + "\n")

            return EXIT_SUCCESS

        except Exception as e:
            self.logger.error(f"Failed to get status: {e}")
            return EXIT_AWS_ERROR

    def outputs(self) -> int:
        """Show stack outputs.

        Returns:
            Exit code
        """
        self._show_outputs()
        return EXIT_SUCCESS

    def _show_outputs(self):
        """Show Terraform outputs."""
        tf_result = self.terraform.output(json_format=False)

        print("\n" + "="*80)
        print("STACK OUTPUTS")
        print("="*80)
        print(tf_result.stdout)
        print("="*80 + "\n")

    def _print_validation_results(self, results):
        """Print validation results."""
        print()
        for result in results:
            symbol = "✓" if result.passed else "✗"
            print(f"  {symbol} {result.test_name}: {result.message}")
            if result.details and self.verbose:
                for key, value in result.details.items():
                    print(f"      {key}: {value}")
        print()


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Deploy Quilt infrastructure with externalized IAM",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Deploy with external IAM
  %(prog)s deploy --config test/fixtures/config.json --pattern external-iam

  # Deploy with inline IAM (dry run)
  %(prog)s deploy --pattern inline-iam --dry-run

  # Validate deployment
  %(prog)s validate

  # Show status
  %(prog)s status

  # Destroy stack
  %(prog)s destroy --auto-approve
        """
    )

    # Commands
    subparsers = parser.add_subparsers(dest="command", help="Command to execute")

    # Create command
    create_parser = subparsers.add_parser("create", help="Create stack configuration")

    # Deploy command
    deploy_parser = subparsers.add_parser("deploy", help="Deploy stack")
    deploy_parser.add_argument("--dry-run", action="store_true", help="Plan only, don't apply")
    deploy_parser.add_argument("--stack-type", choices=["iam", "app", "both"], default="both",
                              help="Stack type to deploy")

    # Validate command
    validate_parser = subparsers.add_parser("validate", help="Validate deployed stack")

    # Destroy command
    destroy_parser = subparsers.add_parser("destroy", help="Destroy stack")

    # Status command
    status_parser = subparsers.add_parser("status", help="Show stack status")

    # Outputs command
    outputs_parser = subparsers.add_parser("outputs", help="Show stack outputs")

    # Common arguments
    for subparser in [create_parser, deploy_parser, validate_parser, destroy_parser,
                      status_parser, outputs_parser]:
        subparser.add_argument("--config", type=Path,
                              default=Path("test/fixtures/config.json"),
                              help="Config file path")
        subparser.add_argument("--pattern", choices=["external-iam", "inline-iam"],
                              default="external-iam",
                              help="Deployment pattern")
        subparser.add_argument("--name", help="Deployment name override")
        subparser.add_argument("--output-dir", type=Path, default=Path(".deploy"),
                              help="Output directory")
        subparser.add_argument("--auto-approve", action="store_true",
                              help="Skip confirmation prompts")
        subparser.add_argument("--verbose", "-v", action="store_true",
                              help="Enable verbose logging")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return EXIT_CONFIG_ERROR

    # Setup logging
    setup_logging(verbose=args.verbose)
    logger = logging.getLogger(__name__)

    try:
        # Load configuration
        config_overrides = {}
        if args.name:
            config_overrides["name"] = args.name
        if args.pattern:
            config_overrides["pattern"] = args.pattern

        config = DeploymentConfig.from_config_file(args.config, **config_overrides)

        # Create deployer
        deployer = StackDeployer(config, args.output_dir, verbose=args.verbose)

        # Execute command
        if args.command == "create":
            return deployer.create()
        elif args.command == "deploy":
            return deployer.deploy(
                dry_run=args.dry_run,
                auto_approve=args.auto_approve,
                stack_type=args.stack_type
            )
        elif args.command == "validate":
            return deployer.validate()
        elif args.command == "destroy":
            return deployer.destroy(auto_approve=args.auto_approve)
        elif args.command == "status":
            return deployer.status()
        elif args.command == "outputs":
            return deployer.outputs()

    except FileNotFoundError as e:
        logger.error(f"Configuration file not found: {e}")
        return EXIT_CONFIG_ERROR
    except ValueError as e:
        logger.error(f"Configuration error: {e}")
        return EXIT_CONFIG_ERROR
    except KeyboardInterrupt:
        logger.info("\nOperation cancelled by user")
        return EXIT_USER_CANCELLED
    except Exception as e:
        logger.error(f"Unexpected error: {e}", exc_info=args.verbose)
        return EXIT_DEPLOYMENT_ERROR


if __name__ == "__main__":
    sys.exit(main())
```

## Dependencies (pyproject.toml)

```toml
[project]
name = "quilt-iac-deployer"
version = "0.1.0"
description = "Deployment script for Quilt infrastructure with externalized IAM"
requires-python = ">=3.8"
dependencies = [
    "boto3>=1.28.0",
    "requests>=2.31.0",
    "jinja2>=3.1.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.4.0",
    "pytest-cov>=4.1.0",
    "black>=23.7.0",
    "mypy>=1.5.0",
    "ruff>=0.0.285",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.uv]
dev-dependencies = [
    "pytest>=7.4.0",
    "pytest-cov>=4.1.0",
    "black>=23.7.0",
    "mypy>=1.5.0",
    "ruff>=0.0.285",
]

[tool.black]
line-length = 100
target-version = ['py38']

[tool.ruff]
line-length = 100
target-version = "py38"

[tool.mypy]
python_version = "3.8"
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true
```

## Usage Examples

### Example 1: Deploy with External IAM

```bash
# Install dependencies
cd deploy
uv sync

# Deploy with external IAM pattern
uv run python tf_deploy.py deploy \
  --config ../test/fixtures/config.json \
  --pattern external-iam \
  --verbose

# Validate deployment
uv run python tf_deploy.py validate --verbose

# Show status
uv run python tf_deploy.py status

# Destroy when done
uv run python tf_deploy.py destroy --auto-approve
```

### Example 2: Dry Run

```bash
# Plan deployment without applying
uv run python tf_deploy.py deploy \
  --config ../test/fixtures/config.json \
  --pattern external-iam \
  --dry-run
```

### Example 3: Deploy Inline IAM

```bash
# Deploy with inline IAM pattern (backward compatible)
uv run python tf_deploy.py deploy \
  --config ../test/fixtures/config.json \
  --pattern inline-iam \
  --name quilt-inline-test
```

## Testing

### Unit Tests

```python
# tests/test_config.py
import pytest
from pathlib import Path
from lib.config import DeploymentConfig


def test_load_config():
    """Test configuration loading."""
    config = DeploymentConfig.from_config_file(
        Path("../test/fixtures/config.json")
    )

    assert config.aws_account_id == "712023778557"
    assert config.aws_region == "us-east-1"
    assert config.vpc_id.startswith("vpc-")
    assert len(config.subnet_ids) >= 2


def test_vpc_selection():
    """Test VPC selection logic."""
    vpcs = [
        {"vpc_id": "vpc-default", "name": "default", "is_default": True},
        {"vpc_id": "vpc-staging", "name": "quilt-staging", "is_default": False},
        {"vpc_id": "vpc-other", "name": "other", "is_default": False},
    ]

    vpc = DeploymentConfig._select_vpc(vpcs)
    assert vpc["vpc_id"] == "vpc-staging"


def test_terraform_vars_external_iam():
    """Test Terraform variables for external IAM."""
    config = DeploymentConfig.from_config_file(
        Path("../test/fixtures/config.json"),
        pattern="external-iam"
    )

    vars = config.to_terraform_vars()
    assert "iam_template_url" in vars
    assert "template_url" in vars
```

## Success Criteria

**Functional**:

- ✅ Script reads config.json successfully
- ✅ Script generates valid Terraform configuration
- ✅ Script deploys IAM stack successfully
- ✅ Script deploys application stack successfully
- ✅ Script validates deployed stacks
- ✅ Script destroys stacks cleanly

**Quality**:

- ✅ Type hints throughout
- ✅ Comprehensive logging
- ✅ Clear error messages
- ✅ Idempotent operations
- ✅ Unit test coverage > 80%

**Usability**:

- ✅ Simple CLI interface
- ✅ Helpful --help output
- ✅ Progress indicators
- ✅ Confirmation prompts for destructive actions

## Future Enhancements

1. **Template Upload**: Auto-upload CloudFormation templates to S3
2. **Multi-Region**: Support deploying to multiple regions
3. **Cost Estimation**: Show estimated costs before deployment
4. **Drift Detection**: Detect configuration drift
5. **Rollback**: Automatic rollback on failure
6. **CI/CD Integration**: GitHub Actions workflow support
7. **State Management**: Better Terraform state management
8. **Configuration Profiles**: Support multiple deployment profiles

## References

- [Testing Guide](07-testing-guide.md)
- [Implementation Summary](06-implementation-summary.md)
- [config.json](../../test/fixtures/config.json)
- [Terraform Documentation](https://www.terraform.io/docs)
- [Boto3 Documentation](https://boto3.amazonaws.com/v1/documentation/api/latest/index.html)

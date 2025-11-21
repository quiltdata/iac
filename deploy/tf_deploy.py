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
from typing import Any

from lib.config import DeploymentConfig
from lib.terraform import TerraformOrchestrator
from lib.validator import StackValidator
from lib.utils import confirm_action, setup_logging, write_terraform_files


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

    def __init__(
        self, config: DeploymentConfig, output_dir: Path, verbose: bool = False
    ) -> None:
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
                output_dir=self.output_dir, config=self.config, pattern=self.config.pattern
            )

            self.logger.info(f"Stack configuration created in {self.output_dir}")
            return EXIT_SUCCESS

        except Exception as e:
            self.logger.error(f"Failed to create configuration: {e}")
            return EXIT_CONFIG_ERROR

    def deploy(
        self, dry_run: bool = False, auto_approve: bool = False, stack_type: str = "both"
    ) -> int:
        """Deploy stack.

        Args:
            dry_run: Plan only, don't apply
            auto_approve: Skip confirmation
            stack_type: "iam", "app", or "both"

        Returns:
            Exit code
        """
        self.logger.info(
            f"Deploying stack (pattern: {self.config.pattern}, type: {stack_type})..."
        )

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
        print("\n" + "=" * 80)
        print("DEPLOYMENT PLAN")
        print("=" * 80)
        print(tf_result.stdout)
        print("=" * 80 + "\n")

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
                self.logger.info("All validation tests passed")
                return EXIT_SUCCESS
            else:
                self.logger.error("Some validation tests failed")
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
            if not confirm_action(
                f"Destroy stack {self.config.deployment_name}? This cannot be undone!"
            ):
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

            print("\n" + "=" * 80)
            print("STACK STATUS")
            print("=" * 80)
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

            print("=" * 80 + "\n")

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

    def _show_outputs(self) -> None:
        """Show Terraform outputs."""
        tf_result = self.terraform.output(json_format=False)

        print("\n" + "=" * 80)
        print("STACK OUTPUTS")
        print("=" * 80)
        print(tf_result.stdout)
        print("=" * 80 + "\n")

    def _print_validation_results(self, results: Any) -> None:
        """Print validation results.

        Args:
            results: List of ValidationResult objects
        """
        print()
        for result in results:
            symbol = "✓" if result.passed else "✗"
            print(f"  {symbol} {result.test_name}: {result.message}")
            if result.details and self.verbose:
                for key, value in result.details.items():
                    print(f"      {key}: {value}")
        print()


def main() -> int:
    """Main entry point.

    Returns:
        Exit code
    """
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
        """,
    )

    # Commands
    subparsers = parser.add_subparsers(dest="command", help="Command to execute")

    # Create command
    create_parser = subparsers.add_parser("create", help="Create stack configuration")

    # Deploy command
    deploy_parser = subparsers.add_parser("deploy", help="Deploy stack")
    deploy_parser.add_argument(
        "--dry-run", action="store_true", help="Plan only, don't apply"
    )
    deploy_parser.add_argument(
        "--stack-type",
        choices=["iam", "app", "both"],
        default="both",
        help="Stack type to deploy",
    )

    # Validate command
    validate_parser = subparsers.add_parser("validate", help="Validate deployed stack")

    # Destroy command
    destroy_parser = subparsers.add_parser("destroy", help="Destroy stack")

    # Status command
    status_parser = subparsers.add_parser("status", help="Show stack status")

    # Outputs command
    outputs_parser = subparsers.add_parser("outputs", help="Show stack outputs")

    # Common arguments
    for subparser in [
        create_parser,
        deploy_parser,
        validate_parser,
        destroy_parser,
        status_parser,
        outputs_parser,
    ]:
        subparser.add_argument(
            "--config",
            type=Path,
            default=Path("../test/fixtures/config.json"),
            help="Config file path (default: ../test/fixtures/config.json)",
        )
        subparser.add_argument(
            "--pattern",
            choices=["external-iam", "inline-iam"],
            default="external-iam",
            help="Deployment pattern",
        )
        subparser.add_argument("--name", help="Deployment name override")
        subparser.add_argument(
            "--output-dir",
            type=Path,
            default=Path(".deploy"),
            help="Output directory",
        )
        subparser.add_argument(
            "--auto-approve", action="store_true", help="Skip confirmation prompts"
        )
        subparser.add_argument(
            "--verbose", "-v", action="store_true", help="Enable verbose logging"
        )

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return EXIT_CONFIG_ERROR

    # Setup logging
    setup_logging(verbose=args.verbose)
    logger = logging.getLogger(__name__)

    try:
        # Load configuration
        config_overrides: dict[str, Any] = {}
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
                stack_type=args.stack_type,
            )
        elif args.command == "validate":
            return deployer.validate()
        elif args.command == "destroy":
            return deployer.destroy(auto_approve=args.auto_approve)
        elif args.command == "status":
            return deployer.status()
        elif args.command == "outputs":
            return deployer.outputs()

        return EXIT_SUCCESS

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

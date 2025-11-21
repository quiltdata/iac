"""Stack validation."""

import logging
from dataclasses import dataclass
from typing import Any, Dict, List, Optional

import boto3
import requests

logger = logging.getLogger(__name__)


@dataclass
class ValidationResult:
    """Validation result."""

    passed: bool
    test_name: str
    message: str
    details: Optional[Dict[str, Any]] = None


class StackValidator:
    """Stack validator."""

    def __init__(self, aws_region: str) -> None:
        """Initialize validator.

        Args:
            aws_region: AWS region
        """
        self.aws_region = aws_region
        self.cf_client = boto3.client("cloudformation", region_name=aws_region)
        self.iam_client = boto3.client("iam", region_name=aws_region)
        self.elbv2_client = boto3.client("elbv2", region_name=aws_region)

    def validate_stack(
        self, stack_name: str, expected_resources: Optional[Dict[str, int]] = None
    ) -> List[ValidationResult]:
        """Validate CloudFormation stack.

        Args:
            stack_name: Stack name
            expected_resources: Expected resource counts by type

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
        results.extend(
            self.validate_stack(
                stack_name,
                expected_resources={"AWS::IAM::Role": 24, "AWS::IAM::ManagedPolicy": 8},
            )
        )

        # Test: All outputs are valid ARNs
        results.append(self._validate_iam_outputs(stack_name))

        # Test: IAM resources exist in AWS
        results.append(self._validate_iam_resources_exist(stack_name))

        return results

    def validate_app_stack(
        self, stack_name: str, iam_stack_name: Optional[str] = None
    ) -> List[ValidationResult]:
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
        """Validate stack exists.

        Args:
            stack_name: Stack name

        Returns:
            ValidationResult
        """
        try:
            self.cf_client.describe_stacks(StackName=stack_name)
            return ValidationResult(
                passed=True,
                test_name="stack_exists",
                message=f"Stack {stack_name} exists",
            )
        except self.cf_client.exceptions.ClientError:
            return ValidationResult(
                passed=False,
                test_name="stack_exists",
                message=f"Stack {stack_name} does not exist",
            )

    def _validate_stack_status(self, stack_name: str) -> ValidationResult:
        """Validate stack is in successful state.

        Args:
            stack_name: Stack name

        Returns:
            ValidationResult
        """
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
                details={"status": status},
            )
        except Exception as e:
            return ValidationResult(
                passed=False,
                test_name="stack_status",
                message=f"Failed to get stack status: {e}",
            )

    def _validate_resources(
        self, stack_name: str, expected: Optional[Dict[str, int]] = None
    ) -> ValidationResult:
        """Validate resources created.

        Args:
            stack_name: Stack name
            expected: Expected resource counts by type

        Returns:
            ValidationResult
        """
        try:
            response = self.cf_client.describe_stack_resources(StackName=stack_name)
            resources = response["StackResources"]

            # Count by type
            resource_counts: Dict[str, int] = {}
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
                            details=resource_counts,
                        )

            return ValidationResult(
                passed=True,
                test_name="resource_counts",
                message=f"Found {len(resources)} resources",
                details=resource_counts,
            )

        except Exception as e:
            return ValidationResult(
                passed=False,
                test_name="resource_counts",
                message=f"Failed to validate resources: {e}",
            )

    def _validate_iam_outputs(self, stack_name: str) -> ValidationResult:
        """Validate IAM outputs are valid ARNs.

        Args:
            stack_name: Stack name

        Returns:
            ValidationResult
        """
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
                    details={"invalid": invalid_arns},
                )

            return ValidationResult(
                passed=True,
                test_name="iam_output_arns",
                message=f"All {len(outputs)} outputs are valid ARNs",
            )

        except Exception as e:
            return ValidationResult(
                passed=False,
                test_name="iam_output_arns",
                message=f"Failed to validate IAM outputs: {e}",
            )

    def _validate_iam_resources_exist(self, stack_name: str) -> ValidationResult:
        """Validate IAM resources exist in AWS.

        Args:
            stack_name: Stack name

        Returns:
            ValidationResult
        """
        try:
            # List roles with stack name prefix
            response = self.iam_client.list_roles()
            roles = [
                r for r in response["Roles"] if r["RoleName"].startswith(stack_name)
            ]

            if len(roles) < 20:  # Expect at least 20 roles
                return ValidationResult(
                    passed=False,
                    test_name="iam_resources_exist",
                    message=f"Expected at least 20 IAM roles, found {len(roles)}",
                    details={"role_count": len(roles)},
                )

            return ValidationResult(
                passed=True,
                test_name="iam_resources_exist",
                message=f"Found {len(roles)} IAM roles",
            )

        except Exception as e:
            return ValidationResult(
                passed=False,
                test_name="iam_resources_exist",
                message=f"Failed to validate IAM resources: {e}",
            )

    def _validate_iam_parameters(
        self, app_stack_name: str, iam_stack_name: str
    ) -> ValidationResult:
        """Validate application stack has IAM parameters.

        Args:
            app_stack_name: Application stack name
            iam_stack_name: IAM stack name

        Returns:
            ValidationResult
        """
        try:
            response = self.cf_client.describe_stacks(StackName=app_stack_name)
            parameters = response["Stacks"][0].get("Parameters", [])

            # Count IAM parameters (contain "Role" or "Policy")
            iam_params = [
                p
                for p in parameters
                if "Role" in p["ParameterKey"] or "Policy" in p["ParameterKey"]
            ]

            if len(iam_params) < 30:  # Expect at least 30 IAM parameters
                return ValidationResult(
                    passed=False,
                    test_name="iam_parameters",
                    message=f"Expected at least 30 IAM parameters, found {len(iam_params)}",
                    details={"iam_param_count": len(iam_params)},
                )

            return ValidationResult(
                passed=True,
                test_name="iam_parameters",
                message=f"Found {len(iam_params)} IAM parameters",
            )

        except Exception as e:
            return ValidationResult(
                passed=False,
                test_name="iam_parameters",
                message=f"Failed to validate IAM parameters: {e}",
            )

    def _validate_application_accessible(self, stack_name: str) -> ValidationResult:
        """Validate application is accessible.

        Args:
            stack_name: Stack name

        Returns:
            ValidationResult
        """
        try:
            # Get ALB DNS name
            response = self.elbv2_client.describe_load_balancers()
            albs = [
                alb
                for alb in response["LoadBalancers"]
                if stack_name in alb["LoadBalancerName"]
            ]

            if not albs:
                return ValidationResult(
                    passed=False,
                    test_name="application_accessible",
                    message=f"No load balancer found for stack {stack_name}",
                )

            alb_dns = albs[0]["DNSName"]
            url = f"http://{alb_dns}/health"

            # Try to access health endpoint
            response_http = requests.get(url, timeout=10, verify=False)

            if response_http.status_code == 200:
                return ValidationResult(
                    passed=True,
                    test_name="application_accessible",
                    message=f"Application accessible at {url}",
                )
            else:
                return ValidationResult(
                    passed=False,
                    test_name="application_accessible",
                    message=f"Application returned status {response_http.status_code}",
                    details={"status_code": response_http.status_code},
                )

        except Exception as e:
            return ValidationResult(
                passed=False,
                test_name="application_accessible",
                message=f"Failed to access application: {e}",
            )

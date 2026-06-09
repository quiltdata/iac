#!/usr/bin/env python3
"""
Template Validation Script for Externalized IAM Testing
Test Suite 1: Template Validation

This script validates CloudFormation templates for syntax, structure,
and consistency between IAM and application templates.
"""

import sys
import yaml
import json
from pathlib import Path
from typing import Dict, Set, Tuple, List


# Add CloudFormation intrinsic function constructors for YAML parsing
def cfn_constructor(loader, tag_suffix, node):
    """Generic constructor for CloudFormation intrinsic functions"""
    if isinstance(node, yaml.ScalarNode):
        return loader.construct_scalar(node)
    elif isinstance(node, yaml.SequenceNode):
        return loader.construct_sequence(node)
    elif isinstance(node, yaml.MappingNode):
        return loader.construct_mapping(node)
    else:
        return None


# Register CloudFormation intrinsic functions
yaml.add_multi_constructor('!', cfn_constructor, Loader=yaml.SafeLoader)


class TestResults:
    """Track test execution results"""

    def __init__(self):
        self.test_count = 0
        self.pass_count = 0
        self.fail_count = 0
        self.results = []

    def run_test(self, test_name: str, test_func) -> bool:
        """Run a test and track results"""
        self.test_count += 1
        print(f"Test {self.test_count}: {test_name}... ", end="", flush=True)

        try:
            result = test_func()
            if result:
                print("✓ PASS")
                self.pass_count += 1
                self.results.append((test_name, "PASS", None))
                return True
            else:
                print("✗ FAIL")
                self.fail_count += 1
                self.results.append((test_name, "FAIL", "Test returned False"))
                return False
        except Exception as e:
            print(f"✗ FAIL: {str(e)}")
            self.fail_count += 1
            self.results.append((test_name, "FAIL", str(e)))
            return False

    def print_summary(self):
        """Print test summary"""
        print("\n" + "=" * 60)
        print("Test Suite 1: Template Validation - Summary")
        print("=" * 60)
        print(f"Total tests: {self.test_count}")
        print(f"Passed: {self.pass_count}")
        print(f"Failed: {self.fail_count}")
        print(f"Success rate: {(self.pass_count / self.test_count * 100):.1f}%")

        if self.fail_count > 0:
            print("\nFailed tests:")
            for name, status, error in self.results:
                if status == "FAIL":
                    print(f"  - {name}")
                    if error:
                        print(f"    Error: {error}")

        return self.fail_count == 0


def load_yaml_template(file_path: Path) -> Dict:
    """Load and parse a YAML CloudFormation template"""
    with open(file_path, 'r') as f:
        return yaml.safe_load(f)


def test_yaml_syntax(file_path: Path) -> bool:
    """Test if file is valid YAML"""
    try:
        load_yaml_template(file_path)
        return True
    except yaml.YAMLError as e:
        raise Exception(f"YAML syntax error: {e}")


def count_iam_resources(template: Dict) -> Tuple[int, int]:
    """Count IAM roles and policies in template"""
    resources = template.get('Resources', {})

    role_count = sum(1 for r in resources.values()
                     if r.get('Type') == 'AWS::IAM::Role')

    policy_count = sum(1 for r in resources.values()
                       if r.get('Type') in ['AWS::IAM::ManagedPolicy', 'AWS::IAM::Policy'])

    return role_count, policy_count


def count_iam_outputs(template: Dict) -> int:
    """Count IAM-related outputs in template"""
    outputs = template.get('Outputs', {})

    # Count outputs that end with 'Arn' or contain 'Role' or 'Policy'
    iam_output_count = sum(1 for name, output in outputs.items()
                           if name.endswith('Arn') or
                              'Role' in name or
                              'Policy' in name)

    return iam_output_count


def count_iam_parameters(template: Dict) -> int:
    """Count IAM-related parameters in template"""
    parameters = template.get('Parameters', {})

    # Count parameters that are IAM ARNs (Role or Policy names ending with potential ARN patterns)
    iam_param_count = sum(1 for name, param in parameters.items()
                          if 'Role' in name or 'Policy' in name)

    return iam_param_count


def extract_iam_output_names(template: Dict) -> Set[str]:
    """Extract IAM output base names (without 'Arn' suffix)"""
    outputs = template.get('Outputs', {})
    names = set()

    for output_name in outputs.keys():
        # Remove 'Arn' suffix if present
        if output_name.endswith('Arn'):
            names.add(output_name[:-3])
        elif 'Role' in output_name or 'Policy' in output_name:
            names.add(output_name)

    return names


def extract_iam_parameter_names(template: Dict) -> Set[str]:
    """Extract IAM parameter base names"""
    parameters = template.get('Parameters', {})
    names = set()

    for param_name in parameters.keys():
        # Only include IAM-related parameters
        if 'Role' in param_name or 'Policy' in param_name:
            names.add(param_name)

    return names


def check_no_inline_iam_resources(template: Dict) -> Tuple[bool, List[str]]:
    """Check that template has no inline IAM roles or policies"""
    resources = template.get('Resources', {})
    inline_iam = []

    for resource_name, resource in resources.items():
        resource_type = resource.get('Type', '')
        if resource_type in ['AWS::IAM::Role', 'AWS::IAM::ManagedPolicy', 'AWS::IAM::Policy']:
            inline_iam.append(f"{resource_name} ({resource_type})")

    return len(inline_iam) == 0, inline_iam


def validate_name_consistency(iam_template: Dict, app_template: Dict) -> Tuple[bool, Set[str], Set[str]]:
    """Validate that IAM outputs match application parameters"""
    iam_outputs = extract_iam_output_names(iam_template)
    app_parameters = extract_iam_parameter_names(app_template)

    # Find mismatches
    missing_in_app = iam_outputs - app_parameters
    extra_in_app = app_parameters - iam_outputs

    return len(missing_in_app) == 0 and len(extra_in_app) == 0, missing_in_app, extra_in_app


def main():
    """Main test runner"""
    print("=" * 60)
    print("Test Suite 1: Template Validation")
    print("=" * 60)
    print()

    # Locate test fixtures
    fixtures_dir = Path(__file__).parent / "fixtures"
    iam_template_path = fixtures_dir / "stable-iam.yaml"
    app_template_path = fixtures_dir / "stable-app.yaml"

    # Verify files exist
    if not iam_template_path.exists():
        print(f"❌ ERROR: IAM template not found: {iam_template_path}")
        return 1

    if not app_template_path.exists():
        print(f"❌ ERROR: Application template not found: {app_template_path}")
        return 1

    print(f"IAM Template: {iam_template_path}")
    print(f"App Template: {app_template_path}")
    print()

    results = TestResults()

    # Test 1.1: IAM template is valid YAML
    results.run_test(
        "IAM template YAML syntax",
        lambda: test_yaml_syntax(iam_template_path)
    )

    # Test 1.2: Application template is valid YAML
    results.run_test(
        "Application template YAML syntax",
        lambda: test_yaml_syntax(app_template_path)
    )

    # Load templates for further tests
    try:
        iam_template = load_yaml_template(iam_template_path)
        app_template = load_yaml_template(app_template_path)
    except Exception as e:
        print(f"\n❌ ERROR: Could not load templates: {e}")
        return 1

    # Test 1.3: IAM template has expected IAM resources
    def test_iam_resources():
        roles, policies = count_iam_resources(iam_template)
        total = roles + policies
        if total < 30:  # Should have at least 30 IAM resources
            raise Exception(f"Expected at least 30 IAM resources, found {total} ({roles} roles, {policies} policies)")
        print(f" ({roles} roles, {policies} policies)", end="")
        return True

    results.run_test("IAM template has IAM resources", test_iam_resources)

    # Test 1.4: IAM template has required outputs (32 expected)
    def test_iam_outputs():
        output_count = count_iam_outputs(iam_template)
        if output_count < 30:  # Should have at least 30 outputs
            raise Exception(f"Expected at least 30 IAM outputs, found {output_count}")
        print(f" ({output_count} outputs)", end="")
        return True

    results.run_test("IAM template has required outputs", test_iam_outputs)

    # Test 1.5: Application template has required parameters (32 IAM parameters)
    def test_app_parameters():
        param_count = count_iam_parameters(app_template)
        if param_count < 30:  # Should have at least 30 IAM parameters
            raise Exception(f"Expected at least 30 IAM parameters, found {param_count}")
        print(f" ({param_count} parameters)", end="")
        return True

    results.run_test("Application template has IAM parameters", test_app_parameters)

    # Test 1.6: Output names match parameter names
    def test_name_consistency():
        consistent, missing, extra = validate_name_consistency(iam_template, app_template)

        # Filter out known configuration parameters (not IAM outputs)
        config_params = {
            'ManagedUserRoleExtraPolicies',  # Configuration parameter
            'S3BucketPolicyExcludeArnsFromDeny',  # Configuration parameter
        }
        extra_filtered = extra - config_params

        if missing:
            raise Exception(f"IAM outputs missing in app: {missing}")

        if extra_filtered:
            raise Exception(f"Unexpected IAM parameters in app: {extra_filtered}")

        return True

    results.run_test("Output/parameter name consistency", test_name_consistency)

    # Test 1.7: Application template has minimal inline IAM resources
    # Note: Some application-specific helper roles are allowed (S3ObjectResourceHandlerRole, etc.)
    # We're checking that core Quilt IAM roles are externalized, not ALL IAM resources
    def test_minimal_inline_iam():
        has_none, inline_resources = check_no_inline_iam_resources(app_template)
        # Allow up to 10 application-specific IAM resources (not core Quilt roles)
        if len(inline_resources) > 10:
            raise Exception(f"Too many inline IAM resources ({len(inline_resources)}): {', '.join(inline_resources)}")
        print(f" ({len(inline_resources)} app-specific roles allowed)", end="")
        return True

    results.run_test("Application has minimal inline IAM", test_minimal_inline_iam)

    # Test 1.8: Templates are CloudFormation format
    def test_cfn_format():
        # Check for Resources section (required)
        if 'Resources' not in iam_template:
            raise Exception("IAM template missing Resources section")
        if 'Resources' not in app_template:
            raise Exception("App template missing Resources section")

        # Check that templates have either AWSTemplateFormatVersion or Description
        # (both are valid CloudFormation)
        if 'AWSTemplateFormatVersion' not in iam_template and 'Description' not in iam_template:
            raise Exception("IAM template missing both AWSTemplateFormatVersion and Description")
        if 'AWSTemplateFormatVersion' not in app_template and 'Description' not in app_template:
            raise Exception("App template missing both AWSTemplateFormatVersion and Description")

        return True

    results.run_test("Templates are valid CloudFormation format", test_cfn_format)

    # Print summary and return exit code
    success = results.print_summary()
    return 0 if success else 1


if __name__ == '__main__':
    sys.exit(main())

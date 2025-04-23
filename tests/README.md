# Quilt Stack Tag Tests

These tests verify that the Quilt module correctly sets tags on AWS resources.

## Prerequisites

1. AWS credentials configured with appropriate permissions
2. Terraform >= 1.5.0 installed
3. AWS provider ~> 5.0

## Running the Tests

From any directory:

```bash
cd tests && terraform init
cd tests && terraform apply
```

The test will:
1. Create a test stack with minimal configuration
2. Verify the common_tags contain just the stack name
3. Verify the stack_dependent_tags contain both stack name and stack ID
4. Output test results as boolean values

### Test Outputs

- `test_common_tags`: Will be `true` if common_tags are correct
- `test_stack_dependent_tags`: Will be `true` if stack_dependent_tags are correct

### Cleanup

After testing:

```bash
cd tests && terraform destroy
```

## Test Files

- `test_tags.tf`: Main test configuration
- `test.yml`: Minimal CloudFormation template for testing

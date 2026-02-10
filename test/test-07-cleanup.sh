#!/bin/bash
# File: test/test-07-cleanup.sh

set -e

echo "=== Test Suite 7: Deletion and Cleanup ==="

TEST_DIR="test-deployments/external-iam/terraform"
RESULTS_FILE="test-results-07.log"
test_count=0
pass_count=0
fail_count=0

run_test() {
  local test_name="$1"
  local command="$2"

  test_count=$((test_count + 1))
  echo -n "Test $test_count: $test_name... "

  if eval "$command" >> "$RESULTS_FILE" 2>&1; then
    echo "✓ PASS"
    pass_count=$((pass_count + 1))
    return 0
  else
    echo "✗ FAIL"
    fail_count=$((fail_count + 1))
    return 1
  fi
}

cd "$TEST_DIR"

IAM_STACK=$(terraform output -raw iam_stack_name 2>/dev/null || echo "unknown")
APP_STACK=$(terraform output -raw app_stack_name 2>/dev/null || echo "unknown")

# Test 7.1: Terraform destroy plan
run_test "Terraform destroy plan succeeds" \
  "terraform plan -destroy -out=destroy.tfplan -var-file=../../test-config.tfvars"

# Test 7.2: Terraform destroy executes
echo "Test $((test_count + 1)): Terraform destroy (full cleanup)..."
if timeout 20m terraform apply -auto-approve destroy.tfplan >> "$RESULTS_FILE" 2>&1; then
  echo "✓ PASS"
  test_count=$((test_count + 1))
  pass_count=$((pass_count + 1))
else
  echo "✗ FAIL"
  test_count=$((test_count + 1))
  fail_count=$((fail_count + 1))
fi

# Test 7.3: Application stack deleted
run_test "Application stack deleted" \
  "! aws cloudformation describe-stacks --stack-name $APP_STACK 2>&1 | grep -q 'does not exist'"

# Test 7.4: IAM stack deleted
run_test "IAM stack deleted" \
  "! aws cloudformation describe-stacks --stack-name $IAM_STACK 2>&1 | grep -q 'does not exist'"

# Test 7.5: No orphaned IAM roles
run_test "No orphaned IAM roles" \
  "test $(aws iam list-roles --query \"Roles[?starts_with(RoleName, '${IAM_STACK}')].RoleName\" --output text | wc -l) -eq 0"

# Test 7.6: No orphaned IAM policies
run_test "No orphaned IAM policies" \
  "test $(aws iam list-policies --scope Local --query \"Policies[?starts_with(PolicyName, '${IAM_STACK}')].PolicyName\" --output text | wc -l) -eq 0"

# Test 7.7: No orphaned CloudFormation exports
run_test "No orphaned CloudFormation exports" \
  "test $(aws cloudformation list-exports --query \"Exports[?starts_with(Name, '${IAM_STACK}')].Name\" --output text | wc -l) -eq 0"

# Test 7.8: Terraform state clean
run_test "Terraform state is empty" \
  "terraform state list | wc -l | grep -q '^0$'"

# Summary
echo ""
echo "=== Test Suite 7 Summary ==="
echo "Total tests: $test_count"
echo "Passed: $pass_count"
echo "Failed: $fail_count"
echo "Results: $RESULTS_FILE"
echo ""
echo "Cleanup complete!"

cd - >/dev/null

[ $fail_count -eq 0 ] && exit 0 || exit 1

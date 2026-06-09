#!/bin/bash
# File: test/test-03-iam-module-integration.sh
# Test Suite 3: IAM Module Integration
#
# Objective: Verify IAM module deploys and outputs are correct
# Duration: 10-15 minutes

set -e

echo "=== Test Suite 3: IAM Module Integration ==="

TEST_DIR="test-deployments/external-iam/terraform"
RESULTS_FILE="test-results-03.log"
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

# Test 3.1: Terraform init
run_test "Terraform init" \
  "terraform init -upgrade"

# Test 3.2: Terraform plan succeeds
run_test "Terraform plan" \
  "terraform plan -out=test.tfplan -var-file=../../test-config.tfvars"

# Test 3.3: Terraform apply succeeds
echo "Test $((test_count + 1)): Terraform apply (IAM stack deployment)..."
if terraform apply -auto-approve test.tfplan >> "$RESULTS_FILE" 2>&1; then
  echo "✓ PASS"
  test_count=$((test_count + 1))
  pass_count=$((pass_count + 1))
else
  echo "✗ FAIL"
  test_count=$((test_count + 1))
  fail_count=$((fail_count + 1))
  cd - >/dev/null
  exit 1
fi

# Test 3.4: IAM stack exists
run_test "IAM CloudFormation stack exists" \
  "aws cloudformation describe-stacks --stack-name $(terraform output -raw iam_stack_name)"

# Test 3.5: IAM stack is in successful state
run_test "IAM stack status is CREATE_COMPLETE" \
  "test $(aws cloudformation describe-stacks --stack-name $(terraform output -raw iam_stack_name) --query 'Stacks[0].StackStatus' --output text) = 'CREATE_COMPLETE'"

# Test 3.6: All 32 outputs present
run_test "IAM stack has 32 outputs" \
  "test $(terraform output -json all_role_arns | jq 'length') -eq 24 && test $(terraform output -json all_policy_arns | jq 'length') -eq 8"

# Test 3.7: All ARNs have correct format
run_test "All role ARNs are valid" \
  "terraform output -json all_role_arns | jq -r '.[]' | grep -E '^arn:aws:iam::[0-9]{12}:role/'"

run_test "All policy ARNs are valid" \
  "terraform output -json all_policy_arns | jq -r '.[]' | grep -E '^arn:aws:iam::[0-9]{12}:policy/'"

# Test 3.8: IAM resources exist in AWS
STACK_NAME=$(terraform output -raw iam_stack_name)
run_test "IAM roles exist in AWS" \
  "test $(aws iam list-roles --query 'Roles[?starts_with(RoleName, \`${STACK_NAME}\`)].RoleName' --output text | wc -w) -ge 24"

# Test 3.9: Stack has required tags
run_test "IAM stack has required tags" \
  "aws cloudformation describe-stacks --stack-name $STACK_NAME --query 'Stacks[0].Tags[?Key==\`ManagedBy\`].Value' --output text | grep terraform"

# Summary
echo ""
echo "=== Test Suite 3 Summary ==="
echo "Total tests: $test_count"
echo "Passed: $pass_count"
echo "Failed: $fail_count"
echo "Results: $RESULTS_FILE"
echo ""
echo "IAM stack deployed successfully. Run test-04 for full integration test."

cd - >/dev/null

[ $fail_count -eq 0 ] && exit 0 || exit 1

#!/bin/bash
# File: test/test-01-template-validation.sh

set -e

echo "=== Test Suite 1: Template Validation ==="

TEST_DIR="test-deployments/templates"
RESULTS_FILE="test/test-results-01.log"

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

# Test 1.1: IAM template is valid YAML
run_test "IAM template YAML syntax" \
  "python3 -c 'import yaml; yaml.safe_load(open(\"$TEST_DIR/quilt-iam.yaml\"))'"

# Test 1.2: Application template is valid YAML
run_test "Application template YAML syntax" \
  "python3 -c 'import yaml; yaml.safe_load(open(\"$TEST_DIR/quilt-app.yaml\"))'"

# Test 1.3: IAM template passes CloudFormation validation
run_test "IAM template CloudFormation validation" \
  "aws cloudformation validate-template --template-body file://$TEST_DIR/quilt-iam.yaml"

# Test 1.4: Application template passes CloudFormation validation
run_test "Application template CloudFormation validation" \
  "aws cloudformation validate-template --template-body file://$TEST_DIR/quilt-app.yaml"

# Test 1.5: IAM template has required outputs
run_test "IAM template has 32 outputs" \
  "test $(grep -c 'Type:.*AWS::IAM::Role\|Type:.*AWS::IAM::ManagedPolicy' $TEST_DIR/quilt-iam.yaml) -eq 32"

# Test 1.6: Application template has required parameters
run_test "Application template has 32 IAM parameters" \
  "test $(grep -c 'Type: String' $TEST_DIR/quilt-app.yaml | grep -E 'Role|Policy') -ge 32"

# Test 1.7: Output names match parameter names
run_test "Output/parameter name consistency" \
  "python3 test/validate-names.py $TEST_DIR/quilt-iam.yaml $TEST_DIR/quilt-app.yaml"

# Test 1.8: No IAM resources in application template
run_test "Application template has no inline IAM roles/policies" \
  "! grep -E 'Type:.*AWS::IAM::Role|Type:.*AWS::IAM::ManagedPolicy' $TEST_DIR/quilt-app.yaml | grep -v Parameter"

# Summary
echo ""
echo "=== Test Suite 1 Summary ==="
echo "Total tests: $test_count"
echo "Passed: $pass_count"
echo "Failed: $fail_count"
echo "Results: $RESULTS_FILE"

[ $fail_count -eq 0 ] && exit 0 || exit 1

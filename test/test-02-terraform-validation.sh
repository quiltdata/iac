#!/bin/bash
# File: test/test-02-terraform-validation.sh

set -e

echo "=== Test Suite 2: Terraform Module Validation ==="

RESULTS_FILE="test/test-results-02.log"
test_count=0
pass_count=0
fail_count=0

run_test() {
  local test_name="$1"
  local test_dir="$2"
  local command="$3"

  test_count=$((test_count + 1))
  echo -n "Test $test_count: $test_name... "

  cd "$test_dir"
  if eval "$command" >> "../$RESULTS_FILE" 2>&1; then
    echo "✓ PASS"
    pass_count=$((pass_count + 1))
    cd - >/dev/null
    return 0
  else
    echo "✗ FAIL"
    fail_count=$((fail_count + 1))
    cd - >/dev/null
    return 1
  fi
}

# Test 2.1: IAM module syntax
run_test "IAM module terraform validate" \
  "modules/iam" \
  "terraform init -backend=false && terraform validate"

# Test 2.2: Quilt module syntax
run_test "Quilt module terraform validate" \
  "modules/quilt" \
  "terraform init -backend=false && terraform validate"

# Test 2.3: IAM module formatting
run_test "IAM module terraform fmt check" \
  "modules/iam" \
  "terraform fmt -check -recursive"

# Test 2.4: Quilt module formatting
run_test "Quilt module terraform fmt check" \
  "modules/quilt" \
  "terraform fmt -check -recursive"

# Test 2.5: IAM module has required outputs
run_test "IAM module output validation" \
  "." \
  "grep -c 'output.*role.*arn\|output.*policy.*arn' modules/iam/outputs.tf | grep 32"

# Test 2.6: Quilt module has iam_template_url variable
run_test "Quilt module has iam_template_url variable" \
  "." \
  "grep -q 'variable \"iam_template_url\"' modules/quilt/variables.tf"

# Test 2.7: Security scanning (if tfsec available)
if command -v tfsec >/dev/null 2>&1; then
  run_test "Security scan - IAM module" \
    "modules/iam" \
    "tfsec . --minimum-severity HIGH"

  run_test "Security scan - Quilt module" \
    "modules/quilt" \
    "tfsec . --minimum-severity HIGH"
fi

# Summary
echo ""
echo "=== Test Suite 2 Summary ==="
echo "Total tests: $test_count"
echo "Passed: $pass_count"
echo "Failed: $fail_count"
echo "Results: $RESULTS_FILE"

[ $fail_count -eq 0 ] && exit 0 || exit 1

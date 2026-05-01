#!/bin/bash
# File: test/test-04-full-integration.sh
# Test Suite 4: Full Module Integration
#
# Objective: Verify complete external IAM pattern works end-to-end
# Duration: 20-30 minutes

set -e

echo "=== Test Suite 4: Full Module Integration ==="

TEST_DIR="test-deployments/external-iam/terraform"
RESULTS_FILE="test-results-04.log"
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

# Test 4.1: Terraform init
run_test "Terraform init" \
  "terraform init -upgrade"

# Test 4.2: Terraform plan succeeds
run_test "Terraform plan" \
  "terraform plan -out=full-test.tfplan -var-file=../../test-config.tfvars"

# Test 4.3: Terraform apply succeeds (full deployment)
echo "Test $((test_count + 1)): Terraform apply (full deployment with external IAM)..."
echo "This will take 15-20 minutes..."
if timeout 30m terraform apply -auto-approve full-test.tfplan >> "$RESULTS_FILE" 2>&1; then
  echo "✓ PASS"
  test_count=$((test_count + 1))
  pass_count=$((pass_count + 1))
else
  echo "✗ FAIL (timeout or error)"
  test_count=$((test_count + 1))
  fail_count=$((fail_count + 1))
  cd - >/dev/null
  exit 1
fi

# Test 4.4: Both stacks exist
IAM_STACK=$(terraform output -raw iam_stack_name)
APP_STACK=$(terraform output -raw app_stack_name)

run_test "IAM stack exists" \
  "aws cloudformation describe-stacks --stack-name $IAM_STACK"

run_test "Application stack exists" \
  "aws cloudformation describe-stacks --stack-name $APP_STACK"

# Test 4.5: Both stacks in successful state
run_test "IAM stack status is complete" \
  "aws cloudformation describe-stacks --stack-name $IAM_STACK --query 'Stacks[0].StackStatus' --output text | grep -E 'CREATE_COMPLETE|UPDATE_COMPLETE'"

run_test "Application stack status is complete" \
  "aws cloudformation describe-stacks --stack-name $APP_STACK --query 'Stacks[0].StackStatus' --output text | grep -E 'CREATE_COMPLETE|UPDATE_COMPLETE'"

# Test 4.6: Application stack has IAM parameters
run_test "Application stack has IAM role parameters" \
  "test $(aws cloudformation describe-stacks --stack-name $APP_STACK --query 'Stacks[0].Parameters[?contains(ParameterKey, \`Role\`)].ParameterKey' --output text | wc -w) -ge 24"

# Test 4.7: IAM parameters are valid ARNs
run_test "IAM parameters are valid ARNs" \
  "aws cloudformation describe-stacks --stack-name $APP_STACK --query 'Stacks[0].Parameters[?contains(ParameterKey, \`Role\`)].ParameterValue' --output text | grep -E '^arn:aws:iam::[0-9]{12}:role/'"

# Test 4.8: Application is accessible
# Try to get custom URL first, fall back to ALB DNS
if terraform output quilt_url >/dev/null 2>&1; then
  QUILT_URL=$(terraform output -raw quilt_url)
  TEST_SCHEME="https"
else
  # No custom URL, use ALB DNS name (HTTP only)
  ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || \
    aws elbv2 describe-load-balancers \
      --names "$APP_STACK" \
      --query 'LoadBalancers[0].DNSName' \
      --output text)
  QUILT_URL="http://${ALB_DNS}"
  TEST_SCHEME="http"
fi

echo "Testing via: $QUILT_URL"

run_test "Quilt URL is accessible" \
  "curl -f -k -I $QUILT_URL"

# Test 4.9: Health endpoint responds
run_test "Health endpoint responds" \
  "curl -f -k $QUILT_URL/health"

# Test 4.10: Database is accessible (indirect check via health)
run_test "Database connectivity (via health check)" \
  "curl -f -k $QUILT_URL/health | grep -q 'ok\\|healthy'"

# Test 4.11: ElasticSearch is accessible (indirect check)
run_test "ElasticSearch connectivity (via health check)" \
  "curl -f -k $QUILT_URL/health | grep -q 'ok\\|healthy'"

# Test 4.12: ECS service is running
run_test "ECS service is running" \
  "test $(aws ecs describe-services --cluster $APP_STACK --services $APP_STACK --query 'services[0].runningCount' --output text) -gt 0"

# Summary
echo ""
echo "=== Test Suite 4 Summary ==="
echo "Total tests: $test_count"
echo "Passed: $pass_count"
echo "Failed: $fail_count"
echo "Results: $RESULTS_FILE"
echo ""
echo "Full deployment successful!"
echo "Quilt URL: $QUILT_URL"
echo "Admin credentials in terraform output"

cd - >/dev/null

[ $fail_count -eq 0 ] && exit 0 || exit 1

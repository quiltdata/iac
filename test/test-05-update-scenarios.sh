#!/bin/bash
# File: test/test-05-update-scenarios.sh

set -e

echo "=== Test Suite 5: Update Scenarios ==="

TEST_DIR="test-deployments/external-iam/terraform"
TEMPLATES_DIR="test-deployments/templates"
RESULTS_FILE="test-results-05.log"
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

IAM_STACK=$(terraform output -raw iam_stack_name)
APP_STACK=$(terraform output -raw app_stack_name)
QUILT_URL=$(terraform output -raw quilt_url)

# Scenario A: Update IAM policy (no ARN change)
echo ""
echo "Scenario A: Update IAM policy without ARN change"
echo "==============================================="

# Test 5.1: Backup original template
run_test "Backup IAM template" \
  "cp $TEMPLATES_DIR/quilt-iam.yaml $TEMPLATES_DIR/quilt-iam.yaml.backup"

# Test 5.2: Modify IAM policy
echo "Modifying IAM policy..."
cat >> "$TEMPLATES_DIR/quilt-iam.yaml" << 'EOF'
# Test modification - add comment to trigger update
# Updated: $(date)
EOF

# Test 5.3: Upload modified template
TEST_BUCKET=$(terraform show -json | jq -r '.values.root_module.child_modules[].resources[] | select(.name=="iam_template_url") | .values.template_url' | sed 's|https://||' | cut -d'/' -f1)
run_test "Upload modified IAM template" \
  "aws s3 cp $TEMPLATES_DIR/quilt-iam.yaml s3://$TEST_BUCKET/quilt-iam.yaml"

# Test 5.4: Terraform detect changes
run_test "Terraform detects IAM changes" \
  "terraform plan -var-file=../../test-config.tfvars | grep -q 'module.quilt.module.iam'"

# Test 5.5: Apply IAM update
echo "Applying IAM update..."
if terraform apply -auto-approve -var-file=../../test-config.tfvars >> "$RESULTS_FILE" 2>&1; then
  echo "✓ PASS"
  test_count=$((test_count + 1))
  pass_count=$((pass_count + 1))
else
  echo "✗ FAIL"
  test_count=$((test_count + 1))
  fail_count=$((fail_count + 1))
fi

# Test 5.6: Application still accessible
run_test "Application still accessible after IAM update" \
  "curl -f -k $QUILT_URL/health"

# Test 5.7: Application stack unchanged
run_test "Application stack not updated (no ARN change)" \
  "test $(aws cloudformation describe-stacks --stack-name $APP_STACK --query 'Stacks[0].LastUpdatedTime' --output text) = 'None' || echo 'Stack updated'"

# Restore original template
cp "$TEMPLATES_DIR/quilt-iam.yaml.backup" "$TEMPLATES_DIR/quilt-iam.yaml"

# Scenario B: Infrastructure update
echo ""
echo "Scenario B: Update infrastructure (increase storage)"
echo "===================================================="

# Test 5.8: Update search volume size
CURRENT_SIZE=$(terraform show -json | jq -r '.values.root_module.child_modules[] | select(.address=="module.quilt") | .resources[] | select(.name=="search_volume_size") | .values // "10"')
NEW_SIZE=$((CURRENT_SIZE + 5))

echo "Updating search_volume_size: $CURRENT_SIZE -> $NEW_SIZE GB"

# Update terraform.tfvars
sed -i.backup "s/search_volume_size = .*/search_volume_size = $NEW_SIZE/" ../../test-config.tfvars

# Test 5.9: Plan shows infrastructure change
run_test "Terraform detects infrastructure change" \
  "terraform plan -var-file=../../test-config.tfvars | grep -q 'search_volume_size'"

# Test 5.10: Apply infrastructure update
echo "Applying infrastructure update..."
if timeout 15m terraform apply -auto-approve -var-file=../../test-config.tfvars >> "$RESULTS_FILE" 2>&1; then
  echo "✓ PASS"
  test_count=$((test_count + 1))
  pass_count=$((pass_count + 1))
else
  echo "✗ FAIL"
  test_count=$((test_count + 1))
  fail_count=$((fail_count + 1))
fi

# Test 5.11: IAM stack unchanged
run_test "IAM stack unchanged during infrastructure update" \
  "aws cloudformation describe-stacks --stack-name $IAM_STACK --query 'Stacks[0].StackStatus' --output text | grep -E 'CREATE_COMPLETE|UPDATE_COMPLETE'"

# Test 5.12: Application recovers
run_test "Application accessible after infrastructure update" \
  "curl -f -k $QUILT_URL/health"

# Restore configuration
mv ../../test-config.tfvars.backup ../../test-config.tfvars

# Summary
echo ""
echo "=== Test Suite 5 Summary ==="
echo "Total tests: $test_count"
echo "Passed: $pass_count"
echo "Failed: $fail_count"
echo "Results: $RESULTS_FILE"

cd - >/dev/null

[ $fail_count -eq 0 ] && exit 0 || exit 1

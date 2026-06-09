#!/bin/bash
# File: test/test-06-comparison.sh

set -e

echo "=== Test Suite 6: External vs Inline IAM Comparison ==="

EXTERNAL_DIR="test-deployments/external-iam/terraform"
INLINE_DIR="test-deployments/inline-iam/terraform"
RESULTS_FILE="test-results-06.log"
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

# Deploy inline IAM version
echo "Deploying inline IAM version for comparison..."
cd "$INLINE_DIR"

# Setup inline configuration (no iam_template_url)
cat > main.tf << 'EOF'
# Inline IAM configuration (for comparison)
module "quilt" {
  source = "../../../modules/quilt"

  name           = "quilt-iam-test-inline"
  quilt_web_host = "quilt-test-inline.example.com"

  # NO iam_template_url - uses inline IAM
  template_url = "https://quilt-templates.s3.amazonaws.com/quilt-monolithic.yaml"

  # ... rest of configuration ...
}
EOF

terraform init
terraform apply -auto-approve -var-file=../../test-config.tfvars

INLINE_STACK=$(terraform output -raw stack_name)

cd - >/dev/null
cd "$EXTERNAL_DIR"

EXTERNAL_IAM_STACK=$(terraform output -raw iam_stack_name)
EXTERNAL_APP_STACK=$(terraform output -raw app_stack_name)

# Test 6.1: Both deployments successful
run_test "Both deployments in successful state" \
  "aws cloudformation describe-stacks --stack-name $INLINE_STACK --query 'Stacks[0].StackStatus' --output text | grep COMPLETE && \
   aws cloudformation describe-stacks --stack-name $EXTERNAL_APP_STACK --query 'Stacks[0].StackStatus' --output text | grep COMPLETE"

# Test 6.2: Same IAM resources created
echo "Comparing IAM resources..."

# Get inline IAM resources
INLINE_ROLES=$(aws cloudformation describe-stack-resources --stack-name $INLINE_STACK --query 'StackResources[?ResourceType==`AWS::IAM::Role`].LogicalResourceId' --output json | jq -r '.[]' | sort)

# Get external IAM resources
EXTERNAL_ROLES=$(aws cloudformation describe-stack-resources --stack-name $EXTERNAL_IAM_STACK --query 'StackResources[?ResourceType==`AWS::IAM::Role`].LogicalResourceId' --output json | jq -r '.[]' | sort)

run_test "Same number of IAM roles" \
  "test $(echo \"$INLINE_ROLES\" | wc -l) -eq $(echo \"$EXTERNAL_ROLES\" | wc -l)"

run_test "Same IAM role names" \
  "diff <(echo \"$INLINE_ROLES\") <(echo \"$EXTERNAL_ROLES\")"

# Test 6.3: Same application resources
INLINE_APP_RESOURCES=$(aws cloudformation describe-stack-resources --stack-name $INLINE_STACK --query 'StackResources[?ResourceType!=`AWS::IAM::Role` && ResourceType!=`AWS::IAM::Policy` && ResourceType!=`AWS::IAM::ManagedPolicy`].ResourceType' --output json | jq -r '.[]' | sort)

EXTERNAL_APP_RESOURCES=$(aws cloudformation describe-stack-resources --stack-name $EXTERNAL_APP_STACK --query 'StackResources[?ResourceType!=`AWS::IAM::Role` && ResourceType!=`AWS::IAM::Policy` && ResourceType!=`AWS::IAM::ManagedPolicy`].ResourceType' --output json | jq -r '.[]' | sort)

run_test "Same application resource types" \
  "diff <(echo \"$INLINE_APP_RESOURCES\") <(echo \"$EXTERNAL_APP_RESOURCES\")"

# Test 6.4: Same functional behavior
INLINE_URL="https://quilt-test-inline.example.com"
EXTERNAL_URL=$(cd "$EXTERNAL_DIR" && terraform output -raw quilt_url)

run_test "Both endpoints accessible" \
  "curl -f -k -I $INLINE_URL && curl -f -k -I $EXTERNAL_URL"

# Test 6.5: Same response times (within tolerance)
INLINE_TIME=$(curl -o /dev/null -s -w "%{time_total}" -k "$INLINE_URL/health")
EXTERNAL_TIME=$(curl -o /dev/null -s -w "%{time_total}" -k "$EXTERNAL_URL/health")

echo "Response times: Inline=$INLINE_TIME, External=$EXTERNAL_TIME"
run_test "Response times comparable (< 20% difference)" \
  "python3 -c \"import sys; inline=$INLINE_TIME; external=$EXTERNAL_TIME; diff=abs(inline-external)/inline*100; sys.exit(0 if diff < 20 else 1)\""

# Cleanup inline deployment
echo "Cleaning up inline deployment..."
cd "$INLINE_DIR"
terraform destroy -auto-approve -var-file=../../test-config.tfvars

# Summary
echo ""
echo "=== Test Suite 6 Summary ==="
echo "Total tests: $test_count"
echo "Passed: $pass_count"
echo "Failed: $fail_count"
echo "Results: $RESULTS_FILE"

cd - >/dev/null

[ $fail_count -eq 0 ] && exit 0 || exit 1

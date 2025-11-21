#!/bin/bash
# File: test/get-test-url.sh
# Usage: ./test/get-test-url.sh [terraform-dir]

TERRAFORM_DIR="${1:-.}"

cd "$TERRAFORM_DIR"

# Try to get custom URL first
if terraform output quilt_url >/dev/null 2>&1; then
  URL=$(terraform output -raw quilt_url)
  echo "Custom URL (HTTPS): $URL"
  echo ""
  echo "Test commands:"
  echo "  curl -k $URL"
  echo "  curl -k $URL/health"
else
  # No custom URL, get ALB DNS name
  if terraform output alb_dns_name >/dev/null 2>&1; then
    ALB_DNS=$(terraform output -raw alb_dns_name)
  else
    # Fall back to querying CloudFormation stack
    STACK_NAME=$(terraform output -raw app_stack_name 2>/dev/null || \
                 terraform output -raw stack_name 2>/dev/null)
    ALB_DNS=$(aws elbv2 describe-load-balancers \
      --names "$STACK_NAME" \
      --query 'LoadBalancers[0].DNSName' \
      --output text)
  fi

  URL="http://${ALB_DNS}"
  echo "ALB DNS (HTTP only): $URL"
  echo ""
  echo "Test commands:"
  echo "  curl $URL"
  echo "  curl $URL/health"
fi

echo ""
echo "For browser testing: $URL"

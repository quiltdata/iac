#!/bin/bash
# File: test/run_all_tests.sh

set -e

echo "========================================="
echo "Externalized IAM Feature - Full Test Suite"
echo "========================================="
echo ""
echo "This will run all test suites:"
echo "  1. Template Validation      (~5 min)"
echo "  2. Terraform Validation     (~5 min)"
echo "  3. IAM Module Integration   (~15 min)"
echo "  4. Full Integration         (~30 min)"
echo "  5. Update Scenarios         (~45 min)"
echo "  6. Comparison Testing       (~60 min)"
echo "  7. Cleanup                  (~20 min)"
echo ""
echo "Total estimated time: ~3 hours"
echo ""
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted"
  exit 0
fi

# Track results
TOTAL_SUITES=7
PASSED_SUITES=0
FAILED_SUITES=0

START_TIME=$(date +%s)

# Run each test suite
for i in {1..7}; do
  echo ""
  echo "========================================="
  echo "Running Test Suite $i of $TOTAL_SUITES"
  echo "========================================="

  if ./scripts/test-0${i}-*.sh; then
    PASSED_SUITES=$((PASSED_SUITES + 1))
    echo "✓ Test Suite $i PASSED"
  else
    FAILED_SUITES=$((FAILED_SUITES + 1))
    echo "✗ Test Suite $i FAILED"

    # Ask whether to continue
    read -p "Continue to next suite? (yes/no): " CONTINUE
    if [ "$CONTINUE" != "yes" ]; then
      break
    fi
  fi
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
DURATION_MIN=$((DURATION / 60))

# Final summary
echo ""
echo "========================================="
echo "Test Suite Summary"
echo "========================================="
echo "Total suites: $TOTAL_SUITES"
echo "Passed: $PASSED_SUITES"
echo "Failed: $FAILED_SUITES"
echo "Duration: ${DURATION_MIN} minutes"
echo ""

if [ $FAILED_SUITES -eq 0 ]; then
  echo "✓ ALL TESTS PASSED"
  exit 0
else
  echo "✗ SOME TESTS FAILED"
  echo "Review test-results-*.log files for details"
  exit 1
fi

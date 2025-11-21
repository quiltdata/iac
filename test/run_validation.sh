#!/bin/bash
# Script to run template validation tests using uv

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Externalized IAM Feature - Template Validation ==="
echo ""
echo "Running Test Suite 1: Template Validation"
echo "Using uv for Python environment management"
echo ""

# Check if uv is installed
if ! command -v uv &> /dev/null; then
    echo "❌ ERROR: uv is not installed"
    echo "Install with: curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

# Run the validation script with uv
echo "Installing dependencies and running tests..."
echo ""

uv run --with pyyaml validate_templates.py

EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ All template validation tests passed!"
else
    echo "❌ Some template validation tests failed"
fi

exit $EXIT_CODE

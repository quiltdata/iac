# Externalized IAM Testing Suite

This directory contains tests for the externalized IAM feature (#91).

## Quick Start

```bash
# Run Test Suite 1: Template Validation
cd /Users/ernest/GitHub/iac/test
./run_validation.sh
```

## Test Suites

Based on [spec/91-externalized-iam/07-testing-guide.md](../spec/91-externalized-iam/07-testing-guide.md):

### ✅ Implemented

1. **Test Suite 1: Template Validation** (~5 min)
   - Script: `./run_validation.sh`
   - Validates CloudFormation template syntax and structure
   - Checks IAM output/parameter consistency
   - Status: **100% PASSING** (8/8 tests)

### ⏭️ To Be Implemented

2. **Test Suite 2**: Terraform Module Validation (~5 min)
3. **Test Suite 3**: IAM Module Integration (~15 min)
4. **Test Suite 4**: Full Module Integration (~30 min)
5. **Test Suite 5**: Update Scenarios (~45 min)
6. **Test Suite 6**: Comparison Testing (~60 min)
7. **Test Suite 7**: Deletion and Cleanup (~20 min)

## Test Fixtures

Located in `fixtures/`:

- **stable-iam.yaml** - IAM-only CloudFormation template (31 IAM resources)
- **stable-app.yaml** - Application CloudFormation template (with parameterized IAM)
- **config.json** - AWS account configuration data
- **env** - Environment variables

## Requirements

- Python 3.8+
- [uv](https://github.com/astral-sh/uv) - Python package manager
- PyYAML (auto-installed by uv)

### Installing uv

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

## Test Scripts

### validate_templates.py

Python script that validates:
- YAML syntax
- CloudFormation structure
- IAM resource counts
- Output/parameter consistency
- Inline IAM detection

**Usage**:
```bash
uv run --with pyyaml validate_templates.py
```

### run_validation.sh

Wrapper script that:
- Checks for uv installation
- Runs validation tests with dependencies
- Formats output

**Usage**:
```bash
./run_validation.sh
```

## Test Results

See [TEST_RESULTS.md](TEST_RESULTS.md) for detailed test execution results.

**Latest Results**: All tests passing ✅

## Project Structure

```
test/
├── README.md                    # This file
├── TEST_RESULTS.md             # Detailed test results
├── fixtures/                   # Test data
│   ├── stable-iam.yaml        # IAM template
│   ├── stable-app.yaml        # Application template
│   ├── config.json            # AWS configuration
│   └── env                    # Environment variables
├── validate_templates.py       # Template validation script
└── run_validation.sh          # Test runner script
```

## Development

### Adding New Tests

1. Create test script in `test/` directory
2. Add test runner shell script (if needed)
3. Update this README with test description
4. Run tests and document results in TEST_RESULTS.md

### Test Naming Convention

- Python scripts: `<test_suite_name>.py`
- Shell runners: `run_<test_suite_name>.sh`
- Make shell scripts executable: `chmod +x run_*.sh`

## CI/CD Integration

All test scripts return proper exit codes:
- `0` = All tests passed
- `1` = One or more tests failed

Example CI usage:
```bash
cd test
./run_validation.sh || exit 1
```

## References

- [Testing Guide](../spec/91-externalized-iam/07-testing-guide.md) - Complete testing specification
- [IAM Module Spec](../spec/91-externalized-iam/03-spec-iam-module.md) - IAM module design
- [Integration Spec](../spec/91-externalized-iam/05-spec-integration.md) - Integration patterns
- [Operations Guide](../OPERATIONS.md) - Deployment procedures

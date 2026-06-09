# AI Agent Guide for Quilt Infrastructure

This guide helps AI agents (like Claude Code, GitHub Copilot, Cursor, etc.) effectively work with this infrastructure repository. It provides context, conventions, and workflows optimized for AI-assisted development.

## Quick Agent Context

```
Repository: quiltdata/iac
Purpose: Terraform Infrastructure as Code for Quilt platform
Language: HCL (Terraform), Python (deployment tooling)
Test Framework: pytest (Python), shell scripts (integration)
Key Feature: Externalized IAM pattern (issue #91)
```

## Repository Structure

```
iac/
├── Makefile              # Main automation hub (run `make help`)
├── README.md             # User-facing documentation
├── OPERATIONS.md         # Operations guide
├── VARIABLES.md          # Complete variable reference
├── EXAMPLES.md           # Deployment examples
│
├── modules/              # Terraform modules
│   ├── iam/             # IAM resources module
│   └── quilt/           # Main Quilt application module
│
├── deploy/              # Python deployment tooling
│   ├── tf_deploy.py     # Main deployment script
│   ├── lib/             # Python libraries
│   │   ├── config.py    # Configuration management
│   │   ├── terraform.py # Terraform orchestration
│   │   └── utils.py     # Utility functions
│   ├── tests/           # Unit tests (pytest)
│   └── templates/       # CloudFormation templates
│
├── test/                # Integration test scripts
│   ├── fixtures/        # Test fixtures and templates
│   ├── test-*.sh        # Shell-based integration tests
│   └── validate_*.py    # Template validation scripts
│
└── spec/                # Technical specifications
    └── 91-externalized-iam/  # Feature specs for issue #91
        ├── 01-requirements.md
        ├── 03-spec-iam-module.md
        ├── 04-spec-quilt-module.md
        ├── 07-testing-guide.md
        └── 10-github-workflow-spec.md
```

## Key Concepts

### 1. Externalized IAM Pattern

**Problem**: CloudFormation templates with 50+ IAM resources hit AWS limits and make updates slow.

**Solution**: Split IAM resources into a separate stack that can be updated independently.

```
┌─────────────────────────────────────┐
│  Before (Monolithic)                │
├─────────────────────────────────────┤
│  CloudFormation Stack               │
│  ├── 32 IAM Roles                   │
│  ├── 8 IAM Policies                 │
│  ├── Database                        │
│  ├── ElasticSearch                  │
│  ├── ECS                            │
│  └── ... (50+ resources)            │
└─────────────────────────────────────┘
         Single large stack
         Slow updates (20-30 min)

┌─────────────────────────────────────┐
│  After (Externalized IAM)           │
├─────────────────────────────────────┤
│  IAM Stack (separate)               │
│  ├── 32 IAM Roles                   │
│  └── 8 IAM Policies                 │
│                                     │
│  Application Stack                  │
│  ├── Database                        │
│  ├── ElasticSearch                  │
│  ├── ECS (uses IAM role ARNs)       │
│  └── ... (infrastructure only)      │
└─────────────────────────────────────┘
         Two independent stacks
         Fast updates (5-10 min for app)
```

### 2. Deployment Patterns

**Pattern A: External IAM** (recommended for production)
```hcl
module "quilt" {
  source = "github.com/quiltdata/iac//modules/quilt"

  iam_template_url = "s3://bucket/quilt-iam.yaml"
  template_url     = "s3://bucket/quilt-app.yaml"

  # IAM stack deployed first, outputs passed to app stack
}
```

**Pattern B: Inline IAM** (simpler for small deployments)
```hcl
module "quilt" {
  source = "github.com/quiltdata/iac//modules/quilt"

  template_file = "./quilt-monolithic.yaml"

  # Single stack with everything
}
```

### 3. Testing Strategy

```
┌─────────────────────────────────────────────────┐
│ Testing Pyramid                                 │
├─────────────────────────────────────────────────┤
│                                                 │
│        ┌────────────┐                           │
│        │  E2E Tests  │  make test-integration  │
│        │  (1-3 hrs)  │  ⚠️ Creates AWS resources │
│        └────────────┘                           │
│            △                                    │
│           ╱ ╲                                   │
│          ╱   ╲                                  │
│   ┌──────────────┐                              │
│   │ Integration  │  Shell scripts in test/     │
│   │  (15-45 min) │  Validates full deployment  │
│   └──────────────┘                              │
│         △                                       │
│        ╱ ╲                                      │
│       ╱   ╲                                     │
│  ┌────────────┐                                 │
│  │ Unit Tests │   make test (38 tests)          │
│  │ (<1 min)   │   ✅ No AWS credentials needed  │
│  └────────────┘                                 │
│                                                 │
└─────────────────────────────────────────────────┘
```

## Common Agent Workflows

### Workflow 1: Understanding the Codebase

```bash
# Get project overview
make info

# Check what tests exist
make help | grep test

# Read key specifications
cat spec/91-externalized-iam/03-spec-iam-module.md
cat spec/91-externalized-iam/04-spec-quilt-module.md
```

**Agent Context Files** (read these first):
1. `spec/91-externalized-iam/03-spec-iam-module.md` - IAM module architecture
2. `spec/91-externalized-iam/04-spec-quilt-module.md` - Main module architecture
3. `deploy/lib/config.py` - Configuration data structures
4. `modules/quilt/main.tf` - Terraform module entry point

### Workflow 2: Making Code Changes

```bash
# 1. Create tests first (TDD)
cd deploy && pytest tests/test_config.py -k "test_new_feature" -v

# 2. Implement the feature
# Edit deploy/lib/config.py

# 3. Run tests
make test

# 4. Check code quality
make lint

# 5. Format code
make format

# 6. Verify everything passes
make verify
```

**Important Conventions**:
- Write tests in `deploy/tests/test_*.py` following pytest conventions
- Reference spec line numbers in test docstrings: `Spec: 09-tf-deploy-infrastructure-spec.md lines 640-657`
- Use mocking for all AWS services (no actual AWS calls in unit tests)
- Follow existing naming patterns: `test_verb_noun_condition()`

### Workflow 3: Adding New Tests

**Unit Test Example**:
```python
# File: deploy/tests/test_config.py

def test_new_feature_with_valid_input():
    """Test new feature with valid input.

    Spec: <spec-file>.md lines <line-range>

    Description of what this test validates.
    """
    # Arrange
    config = DeploymentConfig(
        deployment_name="test",
        aws_region="us-east-1",
        # ... required fields
    )

    # Act
    result = config.new_feature()

    # Assert
    assert result == expected_value
```

**Template Validation Test**:
```python
# File: test/validate_templates.py

def test_template_has_expected_resources():
    """Test that template contains expected resources."""
    template = load_yaml_template(path)

    # Count resources
    resource_count = len(template.get('Resources', {}))

    # Validate
    assert resource_count >= 30, f"Expected >= 30 resources, got {resource_count}"
```

### Workflow 4: Updating Documentation

**When to Update Docs**:
- After changing module interfaces
- After adding new features
- After changing configuration options
- After updating deployment patterns

**Docs to Update**:
1. Module README: `modules/<module>/README.md`
2. Spec files: `spec/91-externalized-iam/*.md`
3. Main README if user-facing changes
4. OPERATIONS.md for operational procedures

### Workflow 5: Debugging Test Failures

```bash
# Run specific test with verbose output
cd deploy && pytest tests/test_config.py::test_specific_test -vv

# Run with debugging
cd deploy && pytest tests/test_config.py -vv --pdb

# Check test coverage
make test-coverage

# Open coverage report
open deploy/htmlcov/index.html
```

**Common Test Failures**:
1. **Import errors**: Check that `deploy/lib/` modules are importable
2. **Assertion failures**: Verify expected vs actual values match spec
3. **Mock issues**: Ensure AWS services are properly mocked
4. **Path issues**: Use absolute paths or `Path(__file__).parent`

## Agent-Specific Tips

### For Claude Code / Claude Agent

**Context Management**:
- Reference specifications by full path: `spec/91-externalized-iam/03-spec-iam-module.md`
- Use line numbers when referencing code: `deploy/lib/config.py:245`
- Always run `make test` after code changes
- Use `make help` to discover available commands

**Common Tasks**:
```bash
# Understand a module
grep -r "class.*Config" deploy/lib/

# Find test coverage gaps
make test-coverage
open deploy/htmlcov/index.html

# Validate changes
make test-all
```

**Best Practices**:
1. Read the relevant spec file before making changes
2. Write tests before implementation (TDD)
3. Run `make verify` before considering task complete
4. Reference spec line numbers in test docstrings
5. Use existing code patterns (grep for similar examples)

### For GitHub Copilot / Cursor

**Inline Suggestions**:
- Follow existing patterns in `deploy/tests/test_*.py`
- Use pytest fixtures consistently
- Mock AWS services using `monkeypatch`
- Follow Python type hints (see `deploy/lib/*.py`)

**Code Completion Context**:
```python
# Good context comments for better suggestions
# Test configuration with external IAM pattern
# Follows spec 09-tf-deploy-infrastructure-spec.md lines 255-300

def test_terraform_infrastructure_config():
    # Agent gets context: external IAM, terraform config, spec reference
    config = DeploymentConfig(...)
```

### For Windsurf / Aider / Other Agents

**Repository Analysis**:
```bash
# Get file structure
tree -L 3 -I '.git|.terraform|__pycache__|.venv'

# Find all test files
find . -name "test_*.py" -o -name "*_test.py"

# Check test count
grep -r "^def test_" deploy/tests/ | wc -l

# See recent changes
git log --oneline -10
```

## Code Patterns to Follow

### Python Code Style

```python
# Type hints (always use)
from typing import Dict, List, Optional

def process_config(config: DeploymentConfig) -> Dict[str, str]:
    """Process configuration and return parameters.

    Args:
        config: Deployment configuration object

    Returns:
        Dictionary of CloudFormation parameters
    """
    return config.get_required_cfn_parameters()

# Defensive programming
def safe_get(data: Dict, *keys, default=None):
    """Safely navigate nested dictionary."""
    for key in keys:
        if not isinstance(data, dict):
            return default
        data = data.get(key, default)
        if data is default:
            return default
    return data
```

### Terraform Code Style

```hcl
# Resource naming: <module>_<resource>_<purpose>
resource "aws_cloudformation_stack" "iam" {
  name = var.name
  # ...
}

# Variable naming: descriptive and consistent
variable "iam_template_url" {
  type        = string
  description = "S3 URL to IAM CloudFormation template"
}

# Output naming: <resource>_<attribute>
output "iam_stack_id" {
  value       = aws_cloudformation_stack.iam.id
  description = "CloudFormation stack ID for IAM resources"
}
```

### Test Code Style

```python
# Test naming: test_<verb>_<noun>_<condition>
def test_get_required_cfn_parameters():
    """Test required CloudFormation parameters.

    Spec: 09-tf-deploy-infrastructure-spec.md lines 640-657

    Tests that get_required_cfn_parameters() returns the minimal
    required parameters for CloudFormation deployment.
    """
    # Arrange (Given)
    config = DeploymentConfig(...)

    # Act (When)
    params = config.get_required_cfn_parameters()

    # Assert (Then)
    assert params == expected_params
```

## Common Pitfalls (For Agents to Avoid)

### 1. Don't Modify Terraform Modules Directly

❌ **Wrong**:
```bash
# Editing modules directly
vim modules/quilt/main.tf
```

✅ **Right**:
```bash
# Create an issue or spec first
# Then update module with tests
make test-unit  # Ensure tests pass
```

### 2. Don't Skip Test Updates

❌ **Wrong**:
```python
# Only updating implementation
def new_feature():
    return "new behavior"
```

✅ **Right**:
```python
# Update tests first (TDD)
def test_new_feature():
    assert new_feature() == "new behavior"

def new_feature():
    return "new behavior"
```

### 3. Don't Forget Type Hints

❌ **Wrong**:
```python
def process_config(config):
    return config.get_params()
```

✅ **Right**:
```python
def process_config(config: DeploymentConfig) -> Dict[str, str]:
    """Process configuration."""
    return config.get_params()
```

### 4. Don't Hard-Code AWS Resources

❌ **Wrong**:
```python
def deploy():
    boto3.client('ec2').describe_vpcs()  # Real AWS call!
```

✅ **Right**:
```python
@pytest.fixture
def mock_ec2(monkeypatch):
    mock = MagicMock()
    mock.describe_vpcs.return_value = {'Vpcs': []}
    monkeypatch.setattr('boto3.client', lambda s: mock)
    return mock

def test_deploy(mock_ec2):
    deploy()  # Uses mock
```

### 5. Don't Ignore Specifications

❌ **Wrong**:
```python
# Implementing without reading spec
def new_feature():
    return "guessed behavior"
```

✅ **Right**:
```python
# Read spec/91-externalized-iam/XX-spec.md first
# Reference spec in test docstring
def test_new_feature():
    """Test new feature.

    Spec: 03-spec-iam-module.md lines 100-150
    """
    # Implementation matches spec exactly
```

## Quick Command Reference

```bash
# Testing
make test              # Unit tests (38 tests, <1 min)
make test-coverage     # With coverage report
make test-templates    # CloudFormation validation
make test-tf           # Terraform validation
make test-all          # All local tests (no AWS)

# Code Quality
make lint              # All linters
make format            # Auto-fix formatting
make verify            # Full environment check

# Development
make setup             # Install dependencies
make clean             # Clean artifacts
make watch             # Watch mode
make help              # See all commands

# Information
make info              # Project overview
make version           # Tool versions
make check-deps        # Dependency check
```

## Environment Setup for Agents

```bash
# One-time setup
git clone https://github.com/quiltdata/iac.git
cd iac
make setup

# Verify setup
make verify

# Run tests to ensure everything works
make test-quick
```

## Agent Success Metrics

When working on this repository, aim for:

- ✅ All unit tests pass (`make test`)
- ✅ Code coverage ≥ 80% (`make test-coverage`)
- ✅ All linters pass (`make lint`)
- ✅ Code is formatted (`make format`)
- ✅ Environment verification passes (`make verify`)
- ✅ Test docstrings reference specifications
- ✅ New features have corresponding tests
- ✅ Documentation is updated

## Getting Help

If an agent encounters issues:

1. **Check existing patterns**: `grep -r "pattern" .`
2. **Read specifications**: `spec/91-externalized-iam/*.md`
3. **Run diagnostics**: `make verify`
4. **Check test examples**: `deploy/tests/test_*.py`
5. **Review recent changes**: `git log --oneline -20`

## Key Files for Agent Context

### Must Read (Priority 1)
- `spec/91-externalized-iam/03-spec-iam-module.md` - IAM module spec
- `spec/91-externalized-iam/04-spec-quilt-module.md` - Quilt module spec
- `deploy/lib/config.py` - Configuration logic
- `modules/quilt/main.tf` - Module implementation

### Should Read (Priority 2)
- `spec/91-externalized-iam/07-testing-guide.md` - Testing guide
- `spec/91-externalized-iam/10-github-workflow-spec.md` - CI/CD spec
- `deploy/tests/test_config.py` - Test examples
- `OPERATIONS.md` - Operational procedures

### Reference (Priority 3)
- `VARIABLES.md` - Complete variable reference
- `EXAMPLES.md` - Usage examples
- `README.md` - User documentation
- `Makefile` - Automation reference

## Agent Learning Resources

**To understand the codebase**:
1. Run `make info` to see structure
2. Read spec files in order (01, 02, 03, ...)
3. Review test files to understand expected behavior
4. Check git history for recent changes

**To add new functionality**:
1. Read relevant spec (if exists) or create one
2. Write test first (TDD approach)
3. Implement to pass test
4. Run `make test-all` and `make lint`
5. Update documentation if needed

**To fix bugs**:
1. Write failing test that reproduces bug
2. Fix implementation
3. Verify test passes
4. Run full test suite
5. Check no regressions

## Summary

This repository follows infrastructure-as-code best practices with:
- Comprehensive testing (unit + integration)
- Type-safe Python code
- Mocked AWS services for unit tests
- Specification-driven development
- Automated quality checks

Agents should prioritize:
- Reading specifications before coding
- Writing tests before implementation
- Following existing patterns
- Running `make verify` before completion
- Referencing specs in test docstrings

For detailed command reference, run `make help`.

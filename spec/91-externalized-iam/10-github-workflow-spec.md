# GitHub Workflow Specification: Automated Testing for Externalized IAM

**Issue**: [#91 - externalized IAM](https://github.com/quiltdata/quilt-infrastructure/issues/91)

**Date**: 2025-11-20

**Branch**: 91-externalized-iam

**References**:
- [07-testing-guide.md](07-testing-guide.md) - Testing guide
- [08-tf-deploy-spec.md](08-tf-deploy-spec.md) - Terraform deployment specification
- [deploy/tests/](../../deploy/tests/) - Unit test suite
- [Makefile](../../Makefile) - Automation hub with testing targets
- [AGENTS.md](../../AGENTS.md) - AI agent guide

## Executive Summary

This document specifies a GitHub Actions workflow that automatically runs unit tests for the externalized IAM feature on pull request events. The workflow leverages the repository's Makefile targets for consistent testing across local development and CI/CD environments. It focuses on fast, mocked unit tests that validate configuration logic, Terraform orchestration, and utility functions without requiring AWS credentials or actual infrastructure deployment.

**Note**: This workflow uses Makefile targets (`make test-coverage`, `make lint-python`) to ensure consistency between local development and CI/CD. See the [Makefile](../../Makefile) for all available targets and run `make help` for documentation.

## Objectives

### Primary Goals

1. **Fast Feedback**: Provide test results within 2-3 minutes of PR push
2. **No AWS Dependencies**: Run entirely with mocked AWS services
3. **Zero Cost**: No AWS resources created or consumed
4. **Comprehensive Coverage**: Test all Python modules in the deployment tooling
5. **Clear Results**: Generate test reports and coverage metrics
6. **PR Integration**: Display test status directly in pull requests

### Non-Goals

- Integration tests with actual AWS resources (manual testing required)
- End-to-end deployment validation (covered by separate processes)
- Performance benchmarking (not applicable for unit tests)
- Security scanning (handled by separate workflows if needed)

## Workflow Design

### Trigger Events

```yaml
on:
  pull_request:
    branches:
      - main
      - 'feature/**'
      - '**-externalized-iam'
    paths:
      - 'deploy/**'
      - 'modules/**'
      - 'test/**'
      - '.github/workflows/test-externalized-iam.yml'

  push:
    branches:
      - main
      - 'feature/**'
      - '**-externalized-iam'
    paths:
      - 'deploy/**'
      - 'modules/**'
      - 'test/**'

  workflow_dispatch:
    # Manual trigger for testing
```

**Rationale**:
- Trigger on PR events to catch issues before merge
- Trigger on push to main to ensure main branch is always tested
- Include feature branches to support development workflows
- Use path filters to avoid unnecessary runs when only docs change
- Support manual triggering for ad-hoc testing

### Job Structure

```text
┌─────────────────────────────────────────────────────────────┐
│                    Test Workflow                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌───────────────────────────────────────────────────┐    │
│  │ Job: Unit Tests                                   │    │
│  │                                                   │    │
│  │  1. Checkout code                                │    │
│  │  2. Set up Python 3.8, 3.9, 3.10, 3.11, 3.12    │    │
│  │  3. Install dependencies                         │    │
│  │  4. Run pytest with coverage                     │    │
│  │  5. Upload coverage reports                      │    │
│  │  6. Generate test summary                        │    │
│  └───────────────────────────────────────────────────┘    │
│                                                             │
│  ┌───────────────────────────────────────────────────┐    │
│  │ Job: Linting (runs in parallel)                  │    │
│  │                                                   │    │
│  │  1. Checkout code                                │    │
│  │  2. Set up Python 3.11                           │    │
│  │  3. Install linting tools                        │    │
│  │  4. Run black (check only)                       │    │
│  │  5. Run ruff                                     │    │
│  │  6. Run mypy                                     │    │
│  └───────────────────────────────────────────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Matrix Strategy

**Python Version Matrix**:
```yaml
strategy:
  matrix:
    python-version: ['3.8', '3.9', '3.10', '3.11', '3.12']
  fail-fast: false
```

**Rationale**:
- Python 3.8: Minimum supported version (per pyproject.toml)
- Python 3.9-3.11: Common versions in production
- Python 3.12: Latest stable version
- `fail-fast: false`: Show all failures, don't stop on first failure

## Workflow Implementation

### File Location

```
.github/
└── workflows/
    └── test-externalized-iam.yml
```

### Workflow Configuration

```yaml
name: Test Externalized IAM

on:
  pull_request:
    branches:
      - main
      - 'feature/**'
      - '**-externalized-iam'
    paths:
      - 'deploy/**'
      - 'modules/**'
      - 'test/**'
      - '.github/workflows/test-externalized-iam.yml'

  push:
    branches:
      - main
    paths:
      - 'deploy/**'
      - 'modules/**'
      - 'test/**'

  workflow_dispatch:

permissions:
  contents: read
  pull-requests: write  # For PR comments
  checks: write         # For test status

jobs:
  unit-tests:
    name: Unit Tests (Python ${{ matrix.python-version }})
    runs-on: ubuntu-latest

    strategy:
      matrix:
        python-version: ['3.8', '3.9', '3.10', '3.11', '3.12']
      fail-fast: false

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python ${{ matrix.python-version }}
        uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}
          cache: 'pip'
          cache-dependency-path: 'deploy/pyproject.toml'

      - name: Install dependencies
        run: make install-dev

      - name: Run unit tests with coverage
        run: make test-coverage

      - name: Upload coverage to Codecov (Python 3.11 only)
        if: matrix.python-version == '3.11'
        uses: codecov/codecov-action@v4
        with:
          files: ./deploy/coverage.xml
          flags: unit-tests
          name: codecov-umbrella
          fail_ci_if_error: false

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results-py${{ matrix.python-version }}
          path: deploy/test-results/

      - name: Upload coverage report
        if: matrix.python-version == '3.11'
        uses: actions/upload-artifact@v4
        with:
          name: coverage-report
          path: deploy/htmlcov/

      - name: Generate test summary
        if: always()
        run: |
          echo "## Test Results (Python ${{ matrix.python-version }})" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          if [ -f deploy/test-results/junit.xml ]; then
            echo "✅ Tests completed" >> $GITHUB_STEP_SUMMARY
          else
            echo "❌ Tests failed" >> $GITHUB_STEP_SUMMARY
          fi

  lint:
    name: Code Quality Checks
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python 3.11
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'
          cache: 'pip'
          cache-dependency-path: 'deploy/pyproject.toml'

      - name: Install dependencies
        run: make install-dev

      - name: Run code quality checks
        run: make lint-python

      - name: Generate lint summary
        if: always()
        run: |
          echo "## Code Quality Results" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "- Black: Format check" >> $GITHUB_STEP_SUMMARY
          echo "- Ruff: Linting" >> $GITHUB_STEP_SUMMARY
          echo "- Mypy: Type checking" >> $GITHUB_STEP_SUMMARY

  test-summary:
    name: Test Summary
    runs-on: ubuntu-latest
    needs: [unit-tests, lint]
    if: always()

    steps:
      - name: Check test results
        run: |
          echo "## Overall Test Summary" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          if [[ "${{ needs.unit-tests.result }}" == "success" && "${{ needs.lint.result }}" == "success" ]]; then
            echo "✅ All tests passed!" >> $GITHUB_STEP_SUMMARY
            exit 0
          else
            echo "❌ Some tests failed" >> $GITHUB_STEP_SUMMARY
            echo "" >> $GITHUB_STEP_SUMMARY
            echo "- Unit Tests: ${{ needs.unit-tests.result }}" >> $GITHUB_STEP_SUMMARY
            echo "- Linting: ${{ needs.lint.result }}" >> $GITHUB_STEP_SUMMARY
            exit 1
          fi
```

## Test Coverage Requirements

### Minimum Coverage Thresholds

```python
# pytest.ini or pyproject.toml
[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py"]
python_classes = ["Test*"]
python_functions = ["test_*"]
addopts = """
    --verbose
    --strict-markers
    --cov=lib
    --cov-branch
    --cov-fail-under=80
"""
```

**Coverage Targets**:
- Overall coverage: ≥80%
- Critical modules (config, terraform): ≥90%
- Utility modules: ≥75%
- Branch coverage: ≥70%

### Coverage Exemptions

Exclude from coverage:
- Type checking code (`if TYPE_CHECKING:`)
- Abstract methods
- Defensive error handling for impossible states
- Development/debug code

```python
# Example exemption
def impossible_case():  # pragma: no cover
    """This should never happen in production."""
    raise RuntimeError("Impossible state")
```

## Mocking Strategy

### AWS Service Mocking

**Principle**: All AWS API calls must be mocked in unit tests.

**Implementation**:
```python
# Example from test_config.py
@pytest.fixture
def mock_aws_services(monkeypatch):
    """Mock AWS services for testing."""

    # Mock boto3 clients
    mock_ec2 = MagicMock()
    mock_ec2.describe_vpcs.return_value = {
        'Vpcs': [{'VpcId': 'vpc-123', 'IsDefault': False}]
    }

    mock_acm = MagicMock()
    mock_acm.list_certificates.return_value = {
        'CertificateSummaryList': [
            {'CertificateArn': 'arn:aws:acm:...', 'DomainName': '*.example.com'}
        ]
    }

    # Apply mocks
    monkeypatch.setattr('boto3.client', lambda service, **kwargs: {
        'ec2': mock_ec2,
        'acm': mock_acm,
    }[service])

    return {'ec2': mock_ec2, 'acm': mock_acm}
```

### Terraform Mocking

**Principle**: Don't execute real Terraform commands in unit tests.

**Implementation**:
```python
# Example from test_terraform.py
def test_terraform_init(tmp_path, monkeypatch):
    """Test Terraform init without actual execution."""
    orchestrator = TerraformOrchestrator(tmp_path)

    # Mock subprocess.run
    mock_run = MagicMock(return_value=MagicMock(
        returncode=0,
        stdout='Terraform initialized',
        stderr=''
    ))
    monkeypatch.setattr('subprocess.run', mock_run)

    result = orchestrator.init()

    assert result.success
    assert 'Terraform initialized' in result.output
```

## PR Integration Features

### Status Checks

**Required Status Check**:
- `Test Externalized IAM / unit-tests (3.11)` - Primary Python version
- `Test Externalized IAM / lint` - Code quality

**Optional Status Checks**:
- Other Python versions (informational)

### PR Comments (Future Enhancement)

Add automated PR comments with test results:

```yaml
- name: Comment test results on PR
  if: github.event_name == 'pull_request'
  uses: actions/github-script@v7
  with:
    script: |
      const fs = require('fs');
      const coverage = fs.readFileSync('deploy/coverage.txt', 'utf8');

      github.rest.issues.createComment({
        issue_number: context.issue.number,
        owner: context.repo.owner,
        repo: context.repo.repo,
        body: `## Test Results\n\n${coverage}`
      });
```

### Badge Integration

Add workflow badge to README:

```markdown
[![Test Externalized IAM](https://github.com/quiltdata/quilt-infrastructure/actions/workflows/test-externalized-iam.yml/badge.svg)](https://github.com/quiltdata/quilt-infrastructure/actions/workflows/test-externalized-iam.yml)
```

## Performance Optimization

### Caching Strategy

**1. Python Dependencies**:
```yaml
- name: Set up Python
  uses: actions/setup-python@v5
  with:
    python-version: '3.11'
    cache: 'pip'
    cache-dependency-path: 'deploy/pyproject.toml'
```

**2. Test Data** (if needed):
```yaml
- name: Cache test data
  uses: actions/cache@v4
  with:
    path: deploy/tests/fixtures/
    key: test-data-${{ hashFiles('deploy/tests/fixtures/**') }}
```

### Expected Performance

**Timing Breakdown**:
```
Setup Python:        30-45s (with cache: 10-15s)
Install dependencies: 20-30s (with cache: 5-10s)
Run unit tests:      10-20s
Upload artifacts:     5-10s
Total per job:       ~1-2 minutes (with cache)
Total workflow:      ~2-3 minutes (parallel execution)
```

## Error Handling

### Test Failure Scenarios

**1. Test Failures**:
- Mark PR check as failed
- Upload test results artifact
- Add summary to GITHUB_STEP_SUMMARY
- Continue with other jobs (fail-fast: false)

**2. Linting Failures**:
- Mark PR check as failed
- Show detailed diff in logs
- Don't block on formatting issues (informational)

**3. Coverage Failures**:
- Fail if coverage < 80%
- Show coverage report in artifacts
- Add coverage badge to PR comment

### Timeout Protection

```yaml
jobs:
  unit-tests:
    timeout-minutes: 10  # Prevent hung tests
```

## Security Considerations

### Secrets Management

**No Secrets Required**: Unit tests run with mocked services, no AWS credentials needed.

**Future Considerations**:
- If integration tests added, use OIDC for AWS access
- Never commit AWS credentials
- Use GitHub secrets for sensitive data

### Permissions

```yaml
permissions:
  contents: read           # Read repository
  pull-requests: write     # Comment on PRs
  checks: write            # Update check status
```

**Principle**: Minimal permissions for security.

## Maintenance

### Workflow Updates

**When to Update**:
1. New Python version released
2. Dependency updates (pytest, coverage tools)
3. New test directories added
4. Performance optimizations identified

**Update Process**:
1. Test changes in feature branch
2. Verify workflow runs successfully
3. Update this specification
4. Merge to main

### Monitoring

**Key Metrics**:
- Workflow run time (target: <3 minutes)
- Test success rate (target: >95%)
- Coverage percentage (target: >80%)
- Cache hit rate (target: >90%)

**Review Schedule**:
- Monthly: Check run times and success rates
- Quarterly: Update Python versions
- Annually: Review testing strategy

## Migration Plan

### Phase 1: Initial Deployment (Week 1)

1. Create workflow file
2. Test on feature branch
3. Verify all tests pass
4. Enable required status checks

### Phase 2: Optimization (Week 2)

1. Add caching
2. Optimize test execution
3. Add coverage reporting
4. Configure Codecov integration

### Phase 3: Enhancement (Week 3+)

1. Add PR comments with results
2. Add workflow badges
3. Integrate with other CI/CD processes
4. Document for team

## Success Criteria

### Technical Metrics

- ✅ All unit tests pass on Python 3.8-3.12
- ✅ Workflow completes in <3 minutes
- ✅ Code coverage ≥80%
- ✅ No flaky tests (success rate >99%)
- ✅ Zero AWS costs

### Team Metrics

- ✅ PR feedback within 5 minutes
- ✅ Clear failure messages
- ✅ Easy to debug failures
- ✅ No false positives

## Appendix

### Example Test Run Output

```
Run pytest tests/
============================= test session starts ==============================
platform linux -- Python 3.11.0, pytest-7.4.0, pluggy-1.3.0
rootdir: /home/runner/work/iac/iac/deploy
plugins: cov-4.1.0
collected 25 items

tests/test_config.py::test_vpc_selection PASSED                          [  4%]
tests/test_config.py::test_vpc_selection_fallback PASSED                 [  8%]
tests/test_config.py::test_subnet_selection PASSED                       [ 12%]
tests/test_terraform.py::test_terraform_result PASSED                    [ 16%]
tests/test_terraform.py::test_terraform_orchestrator_init PASSED         [ 20%]
tests/test_utils.py::test_render_template PASSED                         [ 24%]
...

---------- coverage: platform linux, python 3.11.0 -----------
Name                     Stmts   Miss  Cover
--------------------------------------------
lib/__init__.py              0      0   100%
lib/config.py              150     15    90%
lib/terraform.py           120     12    90%
lib/utils.py                45      3    93%
--------------------------------------------
TOTAL                      315     30    90%

============================= 25 passed in 2.34s ===============================
```

### Troubleshooting Guide

**Problem**: Tests pass locally but fail in CI

**Solutions**:
1. Check Python version differences
2. Verify dependencies are locked
3. Check for environment-specific code
4. Review test isolation

**Problem**: Workflow is slow

**Solutions**:
1. Enable caching
2. Run jobs in parallel
3. Reduce test fixtures size
4. Profile slow tests

**Problem**: Flaky tests

**Solutions**:
1. Remove time-dependent assertions
2. Improve mocking
3. Add test retries (pytest-rerunfailures)
4. Fix race conditions

## References

- Testing Guide: [07-testing-guide.md](07-testing-guide.md)
- GitHub Actions: https://docs.github.com/en/actions
- pytest: https://docs.pytest.org/
- Coverage.py: https://coverage.readthedocs.io/
- Codecov: https://docs.codecov.com/

# Makefile for Quilt Infrastructure as Code
# Manages testing, validation, and deployment workflows

.PHONY: help
.DEFAULT_GOAL := help

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

# Project directories
DEPLOY_DIR := deploy
TEST_DIR := test
MODULES_DIR := modules
TEMPLATES_DIR := $(DEPLOY_DIR)/templates

# Python/pytest configuration
PYTHON := python3
PYTEST := pytest
PYTEST_ARGS := --verbose --cov=lib --cov-report=term --cov-report=html

# Terraform configuration
TERRAFORM := terraform
TF_MODULES := $(shell find $(MODULES_DIR) -name "*.tf" -exec dirname {} \; | sort -u)

##@ Help

help: ## Display this help message
	@echo "$(BLUE)Quilt Infrastructure as Code - Makefile$(NC)"
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  $(BLUE)%-25s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(YELLOW)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Testing - Unit Tests

.PHONY: test test-unit test-config test-terraform test-utils test-coverage test-watch

test: test-unit ## Run all unit tests (alias for test-unit)

test-unit: ## Run Python unit tests
	@echo "$(GREEN)Running Python unit tests...$(NC)"
	cd $(DEPLOY_DIR) && $(PYTEST) tests/ $(PYTEST_ARGS)

test-config: ## Run configuration tests only
	@echo "$(GREEN)Running configuration tests...$(NC)"
	cd $(DEPLOY_DIR) && $(PYTEST) tests/test_config.py -v

test-terraform: ## Run Terraform orchestrator tests only
	@echo "$(GREEN)Running Terraform orchestrator tests...$(NC)"
	cd $(DEPLOY_DIR) && $(PYTEST) tests/test_terraform.py -v

test-utils: ## Run utility function tests only
	@echo "$(GREEN)Running utility tests...$(NC)"
	cd $(DEPLOY_DIR) && $(PYTEST) tests/test_utils.py -v

test-coverage: ## Run tests with detailed coverage report
	@echo "$(GREEN)Running tests with coverage...$(NC)"
	cd $(DEPLOY_DIR) && $(PYTEST) tests/ \
		--verbose \
		--cov=lib \
		--cov-report=term-missing \
		--cov-report=html \
		--cov-report=xml
	@echo "$(GREEN)Coverage report: $(DEPLOY_DIR)/htmlcov/index.html$(NC)"

test-watch: ## Run tests in watch mode (requires pytest-watch)
	@echo "$(GREEN)Running tests in watch mode...$(NC)"
	cd $(DEPLOY_DIR) && ptw tests/ -- $(PYTEST_ARGS)

##@ Testing - Template Validation

.PHONY: test-templates validate-templates validate-iam validate-app validate-names

test-templates: validate-templates ## Run CloudFormation template validation

validate-templates: ## Validate CloudFormation templates (syntax and structure)
	@echo "$(GREEN)Validating CloudFormation templates...$(NC)"
	cd $(TEST_DIR) && $(PYTHON) validate_templates.py

validate-iam: ## Validate IAM template only
	@echo "$(GREEN)Validating IAM template...$(NC)"
	@if [ -f "$(TEST_DIR)/fixtures/stable-iam.yaml" ]; then \
		aws cloudformation validate-template \
			--template-body file://$(TEST_DIR)/fixtures/stable-iam.yaml \
			--output text > /dev/null && \
		echo "$(GREEN)✓ IAM template is valid$(NC)" || \
		echo "$(RED)✗ IAM template validation failed$(NC)"; \
	else \
		echo "$(YELLOW)⚠ IAM template not found at $(TEST_DIR)/fixtures/stable-iam.yaml$(NC)"; \
	fi

validate-app: ## Validate application template only
	@echo "$(GREEN)Validating application template...$(NC)"
	@if [ -f "$(TEST_DIR)/fixtures/stable-app.yaml" ]; then \
		aws cloudformation validate-template \
			--template-body file://$(TEST_DIR)/fixtures/stable-app.yaml \
			--output text > /dev/null && \
		echo "$(GREEN)✓ Application template is valid$(NC)" || \
		echo "$(RED)✗ Application template validation failed$(NC)"; \
	else \
		echo "$(YELLOW)⚠ Application template not found at $(TEST_DIR)/fixtures/stable-app.yaml$(NC)"; \
	fi

validate-names: ## Validate IAM output/parameter name consistency
	@echo "$(GREEN)Validating IAM output/parameter names...$(NC)"
	cd $(TEST_DIR) && $(PYTHON) validate-names.py \
		fixtures/stable-iam.yaml \
		fixtures/stable-app.yaml

##@ Testing - Terraform Validation

.PHONY: test-tf validate-tf validate-tf-modules fmt-check-tf lint-tf

test-tf: validate-tf ## Run Terraform validation

validate-tf: validate-tf-modules ## Validate all Terraform configurations

validate-tf-modules: ## Validate Terraform module syntax
	@echo "$(GREEN)Validating Terraform modules...$(NC)"
	@for module in $(TF_MODULES); do \
		echo "$(BLUE)Validating $$module...$(NC)"; \
		cd $$module && $(TERRAFORM) init -backend=false > /dev/null && $(TERRAFORM) validate; \
		cd - > /dev/null; \
	done

fmt-check-tf: ## Check Terraform formatting
	@echo "$(GREEN)Checking Terraform formatting...$(NC)"
	@$(TERRAFORM) fmt -check -recursive $(MODULES_DIR) && \
		echo "$(GREEN)✓ All Terraform files are properly formatted$(NC)" || \
		(echo "$(RED)✗ Some files need formatting. Run 'make fmt-tf'$(NC)" && exit 1)

fmt-tf: ## Format Terraform files
	@echo "$(GREEN)Formatting Terraform files...$(NC)"
	$(TERRAFORM) fmt -recursive $(MODULES_DIR)
	@echo "$(GREEN)✓ Formatting complete$(NC)"

lint-tf: ## Lint Terraform with tfsec (if available)
	@echo "$(GREEN)Linting Terraform with tfsec...$(NC)"
	@if command -v tfsec > /dev/null; then \
		tfsec $(MODULES_DIR) --minimum-severity MEDIUM; \
	else \
		echo "$(YELLOW)⚠ tfsec not installed. Install: brew install tfsec$(NC)"; \
	fi

##@ Testing - Code Quality

.PHONY: lint lint-python lint-black lint-ruff lint-mypy format format-python

lint: lint-python ## Run all linting checks

lint-python: lint-black lint-ruff lint-mypy ## Run all Python linters

lint-black: ## Check Python code formatting with black
	@echo "$(GREEN)Checking Python formatting with black...$(NC)"
	cd $(DEPLOY_DIR) && black --check --diff lib/ tests/

lint-ruff: ## Lint Python code with ruff
	@echo "$(GREEN)Linting Python with ruff...$(NC)"
	cd $(DEPLOY_DIR) && ruff check lib/ tests/

lint-mypy: ## Type-check Python code with mypy
	@echo "$(GREEN)Type-checking Python with mypy...$(NC)"
	cd $(DEPLOY_DIR) && mypy lib/

format: format-python ## Format all code

format-python: ## Format Python code with black
	@echo "$(GREEN)Formatting Python code with black...$(NC)"
	cd $(DEPLOY_DIR) && black lib/ tests/
	@echo "$(GREEN)✓ Python formatting complete$(NC)"

##@ Testing - Integration Tests (AWS Required)

.PHONY: test-integration test-iam-module test-full-integration test-cleanup

test-integration: ## Run integration tests (requires AWS credentials)
	@echo "$(YELLOW)⚠ Integration tests require AWS credentials and will create resources$(NC)"
	@echo "$(YELLOW)Press Ctrl+C to cancel, Enter to continue...$(NC)"
	@read confirm
	cd $(TEST_DIR) && ./run_all_tests.sh

test-iam-module: ## Test IAM module integration only
	@echo "$(GREEN)Testing IAM module integration...$(NC)"
	cd $(TEST_DIR) && ./test-03-iam-module-integration.sh

test-full-integration: ## Test full integration (IAM + application)
	@echo "$(GREEN)Testing full integration...$(NC)"
	cd $(TEST_DIR) && ./test-04-full-integration.sh

test-cleanup: ## Clean up test deployments
	@echo "$(GREEN)Cleaning up test deployments...$(NC)"
	cd $(TEST_DIR) && ./test-07-cleanup.sh

##@ Testing - All Tests

.PHONY: test-all test-quick test-ci

test-all: test-unit test-templates validate-tf lint ## Run all local tests (no AWS)

test-quick: test-unit ## Run quick tests (unit tests only)
	@echo "$(GREEN)✓ Quick tests complete$(NC)"

test-ci: ## Run CI tests (for GitHub Actions)
	@echo "$(GREEN)Running CI test suite...$(NC)"
	$(MAKE) test-unit
	$(MAKE) test-coverage
	$(MAKE) lint-python
	$(MAKE) fmt-check-tf
	@echo "$(GREEN)✓ CI tests complete$(NC)"

##@ Development Setup

.PHONY: setup install install-dev install-tools clean clean-all

setup: install-dev ## Set up development environment

install: ## Install Python dependencies
	@echo "$(GREEN)Installing Python dependencies...$(NC)"
	cd $(DEPLOY_DIR) && pip install -e .

install-dev: ## Install development dependencies
	@echo "$(GREEN)Installing development dependencies...$(NC)"
	cd $(DEPLOY_DIR) && pip install -e ".[dev]"

install-tools: ## Install additional development tools
	@echo "$(GREEN)Installing additional tools...$(NC)"
	@echo "$(BLUE)Checking for Terraform...$(NC)"
	@command -v terraform > /dev/null || echo "$(YELLOW)⚠ Terraform not found. Install: brew install terraform$(NC)"
	@echo "$(BLUE)Checking for AWS CLI...$(NC)"
	@command -v aws > /dev/null || echo "$(YELLOW)⚠ AWS CLI not found. Install: brew install awscli$(NC)"
	@echo "$(BLUE)Checking for tfsec...$(NC)"
	@command -v tfsec > /dev/null || echo "$(YELLOW)⚠ tfsec not found. Install: brew install tfsec$(NC)"
	@echo "$(BLUE)Checking for jq...$(NC)"
	@command -v jq > /dev/null || echo "$(YELLOW)⚠ jq not found. Install: brew install jq$(NC)"

clean: ## Clean build artifacts and caches
	@echo "$(GREEN)Cleaning build artifacts...$(NC)"
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".mypy_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".ruff_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true
	rm -rf $(DEPLOY_DIR)/htmlcov 2>/dev/null || true
	rm -rf $(DEPLOY_DIR)/coverage.xml 2>/dev/null || true
	rm -rf $(DEPLOY_DIR)/.coverage 2>/dev/null || true
	@echo "$(GREEN)✓ Clean complete$(NC)"

clean-all: clean ## Clean everything including virtual environments
	@echo "$(GREEN)Cleaning virtual environments...$(NC)"
	rm -rf $(DEPLOY_DIR)/.venv 2>/dev/null || true
	rm -rf $(DEPLOY_DIR)/dist 2>/dev/null || true
	rm -rf $(DEPLOY_DIR)/build 2>/dev/null || true
	rm -rf $(DEPLOY_DIR)/*.egg-info 2>/dev/null || true
	@echo "$(GREEN)✓ Deep clean complete$(NC)"

##@ Deployment

.PHONY: deploy deploy-dev deploy-prod deploy-status deploy-destroy

deploy: ## Run interactive deployment
	@echo "$(GREEN)Starting interactive deployment...$(NC)"
	cd $(DEPLOY_DIR) && $(PYTHON) tf_deploy.py

deploy-dev: ## Deploy to dev environment (non-interactive)
	@echo "$(GREEN)Deploying to dev environment...$(NC)"
	cd $(DEPLOY_DIR) && $(PYTHON) tf_deploy.py --environment dev --yes

deploy-prod: ## Deploy to prod environment (requires confirmation)
	@echo "$(RED)⚠ WARNING: Deploying to PRODUCTION$(NC)"
	@echo "$(YELLOW)Press Ctrl+C to cancel, Enter to continue...$(NC)"
	@read confirm
	cd $(DEPLOY_DIR) && $(PYTHON) tf_deploy.py --environment prod

deploy-status: ## Show deployment status
	@echo "$(GREEN)Checking deployment status...$(NC)"
	@if [ -d "$(DEPLOY_DIR)/.deploy" ]; then \
		echo "$(BLUE)Recent deployments:$(NC)"; \
		ls -lt $(DEPLOY_DIR)/.deploy/*/terraform.tfstate 2>/dev/null | head -5; \
	else \
		echo "$(YELLOW)No deployments found$(NC)"; \
	fi

deploy-destroy: ## Destroy deployment (requires confirmation)
	@echo "$(RED)⚠ WARNING: This will DESTROY infrastructure$(NC)"
	@echo "$(YELLOW)Press Ctrl+C to cancel, Enter to continue...$(NC)"
	@read confirm
	cd $(DEPLOY_DIR) && $(PYTHON) tf_deploy.py --destroy

##@ Documentation

.PHONY: docs docs-coverage docs-api

docs: ## Open main documentation
	@echo "$(GREEN)Opening documentation...$(NC)"
	@if command -v open > /dev/null; then \
		open README.md; \
	else \
		echo "$(YELLOW)README.md$(NC)"; \
	fi

docs-coverage: ## Open coverage report
	@echo "$(GREEN)Opening coverage report...$(NC)"
	@if [ -f "$(DEPLOY_DIR)/htmlcov/index.html" ]; then \
		if command -v open > /dev/null; then \
			open $(DEPLOY_DIR)/htmlcov/index.html; \
		else \
			echo "$(YELLOW)Coverage report: $(DEPLOY_DIR)/htmlcov/index.html$(NC)"; \
		fi; \
	else \
		echo "$(YELLOW)No coverage report found. Run 'make test-coverage' first$(NC)"; \
	fi

docs-api: ## Generate API documentation (if configured)
	@echo "$(YELLOW)API documentation generation not yet configured$(NC)"

##@ Utilities

.PHONY: info version check-deps verify watch

info: ## Show project information
	@echo "$(BLUE)Quilt Infrastructure as Code$(NC)"
	@echo ""
	@echo "$(GREEN)Project Structure:$(NC)"
	@echo "  deploy/       - Deployment scripts and tools"
	@echo "  modules/      - Terraform modules"
	@echo "  test/         - Integration test scripts"
	@echo "  spec/         - Technical specifications"
	@echo ""
	@echo "$(GREEN)Key Files:$(NC)"
	@echo "  deploy/tf_deploy.py    - Main deployment script"
	@echo "  deploy/lib/            - Python libraries"
	@echo "  deploy/tests/          - Unit tests"
	@echo ""
	@echo "$(GREEN)Documentation:$(NC)"
	@echo "  README.md              - Main documentation"
	@echo "  OPERATIONS.md          - Operations guide"
	@echo "  deploy/USAGE.md        - Deployment usage"
	@echo "  spec/91-externalized-iam/ - Feature specifications"

version: ## Show tool versions
	@echo "$(GREEN)Tool Versions:$(NC)"
	@echo "Python:    $$($(PYTHON) --version 2>&1)"
	@echo "Terraform: $$($(TERRAFORM) --version 2>&1 | head -1)"
	@echo "AWS CLI:   $$(aws --version 2>&1)"
	@echo "Pytest:    $$(cd $(DEPLOY_DIR) && $(PYTHON) -m pytest --version 2>&1)"
	@echo ""
	@echo "$(GREEN)Optional Tools:$(NC)"
	@command -v tfsec > /dev/null && echo "tfsec:     $$(tfsec --version 2>&1 | head -1)" || echo "tfsec:     $(YELLOW)not installed$(NC)"
	@command -v black > /dev/null && echo "black:     $$(cd $(DEPLOY_DIR) && black --version 2>&1 | head -1)" || echo "black:     $(YELLOW)not installed$(NC)"
	@command -v ruff > /dev/null && echo "ruff:      $$(cd $(DEPLOY_DIR) && ruff --version 2>&1)" || echo "ruff:      $(YELLOW)not installed$(NC)"
	@command -v mypy > /dev/null && echo "mypy:      $$(cd $(DEPLOY_DIR) && mypy --version 2>&1)" || echo "mypy:      $(YELLOW)not installed$(NC)"

check-deps: ## Check for missing dependencies
	@echo "$(GREEN)Checking dependencies...$(NC)"
	@echo ""
	@echo "$(BLUE)Required:$(NC)"
	@command -v $(PYTHON) > /dev/null && echo "✓ Python" || echo "✗ Python (required)"
	@command -v $(TERRAFORM) > /dev/null && echo "✓ Terraform" || echo "✗ Terraform (required)"
	@command -v aws > /dev/null && echo "✓ AWS CLI" || echo "✗ AWS CLI (required)"
	@command -v jq > /dev/null && echo "✓ jq" || echo "✗ jq (required)"
	@echo ""
	@echo "$(BLUE)Optional:$(NC)"
	@command -v tfsec > /dev/null && echo "✓ tfsec" || echo "○ tfsec (optional - for security scanning)"
	@command -v black > /dev/null && echo "✓ black" || echo "○ black (optional - for code formatting)"
	@command -v ruff > /dev/null && echo "✓ ruff" || echo "○ ruff (optional - for linting)"
	@command -v mypy > /dev/null && echo "✓ mypy" || echo "○ mypy (optional - for type checking)"

verify: check-deps ## Verify development environment is ready
	@echo ""
	@echo "$(GREEN)Verifying Python environment...$(NC)"
	@cd $(DEPLOY_DIR) && $(PYTHON) -c "import boto3; import jinja2; print('✓ Python dependencies installed')" 2>/dev/null || \
		echo "$(YELLOW)⚠ Some Python dependencies missing. Run 'make install-dev'$(NC)"
	@echo ""
	@echo "$(GREEN)Running quick verification tests...$(NC)"
	@$(MAKE) test-quick
	@echo ""
	@echo "$(GREEN)✓ Environment verification complete$(NC)"

watch: ## Watch for changes and run tests
	@echo "$(GREEN)Watching for changes...$(NC)"
	@command -v ptw > /dev/null || (echo "$(YELLOW)pytest-watch not installed. Install: pip install pytest-watch$(NC)" && exit 1)
	$(MAKE) test-watch

##@ CI/CD

.PHONY: ci ci-test ci-lint ci-validate

ci: ci-test ci-lint ci-validate ## Run full CI pipeline

ci-test: ## CI: Run tests
	@echo "$(GREEN)CI: Running tests...$(NC)"
	$(MAKE) test-unit

ci-lint: ## CI: Run linting
	@echo "$(GREEN)CI: Running linters...$(NC)"
	$(MAKE) lint-python
	$(MAKE) fmt-check-tf

ci-validate: ## CI: Run validation
	@echo "$(GREEN)CI: Running validation...$(NC)"
	$(MAKE) validate-tf-modules

##@ Shortcuts

.PHONY: t tc tt tu l f v d

t: test-unit ## Shortcut for test-unit
tc: test-coverage ## Shortcut for test-coverage
tt: test-templates ## Shortcut for test-templates
tu: test-unit ## Shortcut for test-unit
l: lint ## Shortcut for lint
f: format ## Shortcut for format
v: verify ## Shortcut for verify
d: deploy ## Shortcut for deploy

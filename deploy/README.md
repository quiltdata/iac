# Quilt IAC Deployer

Deployment script for Quilt infrastructure with externalized IAM.

## Installation

```bash
cd deploy
uv sync
```

## Usage

```bash
# Deploy with external IAM pattern
uv run python tf_deploy.py deploy \
  --config ../test/fixtures/config.json \
  --pattern external-iam \
  --verbose

# Validate deployment
uv run python tf_deploy.py validate --verbose

# Show status
uv run python tf_deploy.py status

# Destroy when done
uv run python tf_deploy.py destroy --auto-approve
```

## Commands

- `create` - Create stack configuration files
- `deploy` - Deploy stack (create + apply)
- `validate` - Validate deployed stack
- `destroy` - Destroy stack
- `status` - Show stack status
- `outputs` - Show stack outputs

## Options

- `--config PATH` - Config file path (default: test/fixtures/config.json)
- `--pattern TYPE` - Pattern: external-iam or inline-iam (default: external-iam)
- `--name NAME` - Deployment name (default: from config)
- `--dry-run` - Show plan without applying
- `--auto-approve` - Skip confirmation prompts
- `--verbose` - Enable verbose logging
- `--output-dir PATH` - Output directory (default: .deploy)
- `--stack-type TYPE` - Stack type: iam, app, or both (default: both)

## Development

```bash
# Run tests
uv run pytest

# Format code
uv run black .

# Lint code
uv run ruff check .

# Type check
uv run mypy .
```

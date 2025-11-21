"""Tests for Terraform orchestrator."""

from lib.terraform import TerraformOrchestrator, TerraformResult


def test_terraform_result():
    """Test TerraformResult dataclass."""
    result = TerraformResult(
        success=True,
        command="terraform init",
        stdout="Success!",
        stderr="",
        return_code=0,
    )

    assert result.success is True
    assert result.output == "Success!"


def test_terraform_result_with_error():
    """Test TerraformResult with error."""
    result = TerraformResult(
        success=False,
        command="terraform apply",
        stdout="Output",
        stderr="Error!",
        return_code=1,
    )

    assert result.success is False
    assert result.output == "OutputError!"


def test_terraform_orchestrator_init(tmp_path):
    """Test TerraformOrchestrator initialization."""
    orchestrator = TerraformOrchestrator(tmp_path)

    assert orchestrator.working_dir == tmp_path
    assert orchestrator.terraform_bin == "terraform"
    assert tmp_path.exists()


def test_terraform_orchestrator_custom_bin(tmp_path):
    """Test TerraformOrchestrator with custom binary."""
    orchestrator = TerraformOrchestrator(tmp_path, terraform_bin="/usr/bin/terraform")

    assert orchestrator.terraform_bin == "/usr/bin/terraform"


def test_get_outputs_empty(tmp_path):
    """Test get_outputs with no outputs."""
    orchestrator = TerraformOrchestrator(tmp_path)

    # This will fail because there's no terraform state, but should return empty dict
    outputs = orchestrator.get_outputs()
    assert outputs == {}


def test_get_outputs_invalid_json(tmp_path, monkeypatch):
    """Test get_outputs with invalid JSON."""
    orchestrator = TerraformOrchestrator(tmp_path)

    # Mock the output method to return invalid JSON
    def mock_output(name=None, json_format=True):
        return TerraformResult(
            success=True,
            command="terraform output",
            stdout="not valid json",
            stderr="",
            return_code=0,
        )

    monkeypatch.setattr(orchestrator, "output", mock_output)

    outputs = orchestrator.get_outputs()
    assert outputs == {}

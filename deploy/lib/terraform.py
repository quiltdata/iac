"""Terraform orchestration."""

import json
import logging
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)


@dataclass
class TerraformResult:
    """Result of a Terraform operation."""

    success: bool
    command: str
    stdout: str
    stderr: str
    return_code: int

    @property
    def output(self) -> str:
        """Combined output.

        Returns:
            Combined stdout and stderr
        """
        return self.stdout + self.stderr


class TerraformOrchestrator:
    """Terraform command orchestrator."""

    def __init__(self, working_dir: Path, terraform_bin: str = "terraform") -> None:
        """Initialize orchestrator.

        Args:
            working_dir: Working directory for Terraform
            terraform_bin: Path to terraform binary
        """
        self.working_dir = working_dir
        self.terraform_bin = terraform_bin
        self.working_dir.mkdir(parents=True, exist_ok=True)

    def init(self, backend_config: Optional[Dict[str, str]] = None) -> TerraformResult:
        """Run terraform init.

        Args:
            backend_config: Backend configuration overrides

        Returns:
            TerraformResult
        """
        cmd = [self.terraform_bin, "init", "-upgrade"]

        if backend_config:
            for key, value in backend_config.items():
                cmd.extend(["-backend-config", f"{key}={value}"])

        return self._run_command(cmd)

    def validate(self) -> TerraformResult:
        """Run terraform validate.

        Returns:
            TerraformResult
        """
        return self._run_command([self.terraform_bin, "validate"])

    def plan(
        self, var_file: Optional[Path] = None, out_file: Optional[Path] = None
    ) -> TerraformResult:
        """Run terraform plan.

        Args:
            var_file: Path to variables file
            out_file: Path to save plan

        Returns:
            TerraformResult
        """
        cmd = [self.terraform_bin, "plan"]

        if var_file:
            cmd.extend(["-var-file", str(var_file)])

        if out_file:
            cmd.extend(["-out", str(out_file)])

        return self._run_command(cmd)

    def apply(
        self,
        plan_file: Optional[Path] = None,
        var_file: Optional[Path] = None,
        auto_approve: bool = False,
    ) -> TerraformResult:
        """Run terraform apply.

        Args:
            plan_file: Path to plan file
            var_file: Path to variables file
            auto_approve: Auto-approve changes

        Returns:
            TerraformResult
        """
        cmd = [self.terraform_bin, "apply"]

        if plan_file:
            # When applying a plan file, don't use -auto-approve
            # (plan is already approved)
            cmd.append(str(plan_file))
        elif var_file:
            cmd.extend(["-var-file", str(var_file)])
            if auto_approve:
                cmd.append("-auto-approve")
        elif auto_approve:
            # No plan file, no var file, just auto-approve
            cmd.append("-auto-approve")

        return self._run_command(cmd)

    def destroy(
        self, var_file: Optional[Path] = None, auto_approve: bool = False
    ) -> TerraformResult:
        """Run terraform destroy.

        Args:
            var_file: Path to variables file
            auto_approve: Auto-approve destruction

        Returns:
            TerraformResult
        """
        cmd = [self.terraform_bin, "destroy"]

        if var_file:
            cmd.extend(["-var-file", str(var_file)])

        if auto_approve:
            cmd.append("-auto-approve")

        return self._run_command(cmd)

    def output(self, name: Optional[str] = None, json_format: bool = True) -> TerraformResult:
        """Run terraform output.

        Args:
            name: Specific output name (if None, all outputs)
            json_format: Output as JSON

        Returns:
            TerraformResult
        """
        cmd = [self.terraform_bin, "output"]

        if json_format:
            cmd.append("-json")

        if name:
            cmd.append(name)

        return self._run_command(cmd)

    def get_outputs(self) -> Dict[str, Any]:
        """Get all outputs as dict.

        Returns:
            Dict of outputs (empty dict if error)
        """
        result = self.output(json_format=True)
        if not result.success:
            return {}

        try:
            outputs = json.loads(result.stdout)
            return {k: v.get("value") for k, v in outputs.items()}
        except json.JSONDecodeError:
            logger.error("Failed to parse terraform output JSON")
            return {}

    def _run_command(self, cmd: List[str]) -> TerraformResult:
        """Run terraform command.

        Args:
            cmd: Command and arguments

        Returns:
            TerraformResult
        """
        logger.info(f"Running: {' '.join(cmd)}")

        try:
            # Use Popen to stream output in real-time while capturing it
            process = subprocess.Popen(
                cmd,
                cwd=self.working_dir,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,  # Merge stderr into stdout
                text=True,
                bufsize=1,  # Line buffered
            )

            stdout_lines = []
            if process.stdout:
                for line in process.stdout:
                    print(line, end="")  # Stream to console in real-time
                    stdout_lines.append(line)

            return_code = process.wait(timeout=3600)  # 1 hour timeout
            stdout = "".join(stdout_lines)

            return TerraformResult(
                success=return_code == 0,
                command=" ".join(cmd),
                stdout=stdout,
                stderr="",  # Already merged into stdout
                return_code=return_code,
            )

        except subprocess.TimeoutExpired:
            logger.error("Terraform command timed out")
            if process:
                process.kill()
            return TerraformResult(
                success=False,
                command=" ".join(cmd),
                stdout="".join(stdout_lines) if "stdout_lines" in locals() else "",
                stderr="Command timed out after 1 hour",
                return_code=124,
            )

        except Exception as e:
            logger.error(f"Failed to run terraform command: {e}")
            return TerraformResult(
                success=False,
                command=" ".join(cmd),
                stdout="",
                stderr=str(e),
                return_code=1,
            )

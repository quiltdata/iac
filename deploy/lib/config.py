"""Configuration management for deployment script."""

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional


@dataclass
class DeploymentConfig:
    """Deployment configuration."""

    # Identity
    deployment_name: str
    aws_region: str
    aws_account_id: str
    environment: str

    # Network
    vpc_id: str
    subnet_ids: List[str]
    security_group_ids: List[str]

    # DNS/TLS
    certificate_arn: str
    route53_zone_id: str
    domain_name: str
    quilt_web_host: str

    # Configuration
    admin_email: str
    pattern: str  # "external-iam" or "inline-iam"

    # Templates
    iam_template_url: Optional[str] = None
    app_template_url: Optional[str] = None

    # Options
    db_instance_class: str = "db.t3.micro"
    search_instance_type: str = "t3.small.elasticsearch"
    search_volume_size: int = 10

    @classmethod
    def from_config_file(cls, config_path: Path, **overrides: Any) -> "DeploymentConfig":
        """Load configuration from config.json.

        Args:
            config_path: Path to config.json
            **overrides: Override configuration values

        Returns:
            DeploymentConfig instance

        Raises:
            FileNotFoundError: If config file not found
            ValueError: If required configuration is missing or invalid
        """
        with open(config_path) as f:
            config = json.load(f)

        # Extract and validate required fields
        deployment_name = overrides.get("name", f"quilt-{config['environment']}")

        # Select appropriate VPC (prefer quilt-staging)
        vpc = cls._select_vpc(config["detected"]["vpcs"])

        # Select public subnets in that VPC
        subnets = cls._select_subnets(config["detected"]["subnets"], vpc["vpc_id"])

        # Select security groups in that VPC
        security_groups = cls._select_security_groups(
            config["detected"]["security_groups"], vpc["vpc_id"]
        )

        # Select certificate matching domain
        # Note: config.json has typo "dommain" instead of "domain"
        domain = config.get("domain") or config.get("dommain", "quilttest.com")
        certificate = cls._select_certificate(config["detected"]["certificates"], domain)

        # Select Route53 zone matching domain
        zone = cls._select_route53_zone(config["detected"]["route53_zones"], domain)

        return cls(
            deployment_name=deployment_name,
            aws_region=config["region"],
            aws_account_id=config["account_id"],
            environment=config["environment"],
            vpc_id=vpc["vpc_id"],
            subnet_ids=[s["subnet_id"] for s in subnets],
            security_group_ids=[sg["security_group_id"] for sg in security_groups],
            certificate_arn=certificate["arn"],
            route53_zone_id=zone["zone_id"],
            domain_name=domain,
            quilt_web_host=f"{deployment_name}.{domain}",
            admin_email=config["email"],
            pattern=overrides.get("pattern", "external-iam"),
            **{
                k: v
                for k, v in overrides.items()
                if k not in ["name", "pattern"]
            },
        )

    @staticmethod
    def _select_vpc(vpcs: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Select VPC (prefer quilt-staging, then first non-default).

        Args:
            vpcs: List of VPC definitions

        Returns:
            Selected VPC

        Raises:
            ValueError: If no suitable VPC found
        """
        # Prefer quilt-staging VPC
        for vpc in vpcs:
            if vpc["name"] == "quilt-staging":
                return vpc

        # Fall back to first non-default VPC
        for vpc in vpcs:
            if not vpc["is_default"]:
                return vpc

        raise ValueError("No suitable VPC found")

    @staticmethod
    def _select_subnets(
        subnets: List[Dict[str, Any]], vpc_id: str
    ) -> List[Dict[str, Any]]:
        """Select public subnets in the VPC (need at least 2).

        Args:
            subnets: List of subnet definitions
            vpc_id: VPC ID to filter by

        Returns:
            List of selected subnets

        Raises:
            ValueError: If fewer than 2 public subnets found
        """
        public_subnets = [
            s
            for s in subnets
            if s["vpc_id"] == vpc_id and s["classification"] == "public"
        ]

        if len(public_subnets) < 2:
            raise ValueError(
                f"Need at least 2 public subnets, found {len(public_subnets)}"
            )

        return public_subnets[:2]  # Return first 2

    @staticmethod
    def _select_security_groups(
        security_groups: List[Dict[str, Any]], vpc_id: str
    ) -> List[Dict[str, Any]]:
        """Select security groups in the VPC.

        Args:
            security_groups: List of security group definitions
            vpc_id: VPC ID to filter by

        Returns:
            List of selected security groups

        Raises:
            ValueError: If no suitable security groups found
        """
        sgs = [
            sg
            for sg in security_groups
            if sg["vpc_id"] == vpc_id and sg.get("in_use", False)
        ]

        if not sgs:
            raise ValueError(f"No suitable security groups found in VPC {vpc_id}")

        return sgs[:3]  # Return up to 3

    @staticmethod
    def _select_certificate(
        certificates: List[Dict[str, Any]], domain: str
    ) -> Dict[str, Any]:
        """Select certificate matching domain.

        Args:
            certificates: List of certificate definitions
            domain: Domain name to match

        Returns:
            Selected certificate

        Raises:
            ValueError: If no valid certificate found
        """
        for cert in certificates:
            if cert["domain_name"] == f"*.{domain}":
                if cert["status"] == "ISSUED":
                    return cert

        raise ValueError(f"No valid certificate found for domain {domain}")

    @staticmethod
    def _select_route53_zone(
        zones: List[Dict[str, Any]], domain: str
    ) -> Dict[str, Any]:
        """Select Route53 zone matching domain.

        Args:
            zones: List of Route53 zone definitions
            domain: Domain name to match

        Returns:
            Selected zone

        Raises:
            ValueError: If no Route53 zone found
        """
        for zone in zones:
            if zone["domain_name"] == f"{domain}.":
                if not zone["private"]:
                    return zone

        raise ValueError(f"No Route53 zone found for domain {domain}")

    def to_terraform_vars(self) -> Dict[str, Any]:
        """Convert to Terraform variables.

        Returns:
            Dictionary of Terraform variables

        Raises:
            ValueError: If required template URLs are missing
        """
        vars_dict = {
            "name": self.deployment_name,
            "aws_region": self.aws_region,
            "aws_account_id": self.aws_account_id,
            "vpc_id": self.vpc_id,
            "subnet_ids": self.subnet_ids,
            "certificate_arn": self.certificate_arn,
            "route53_zone_id": self.route53_zone_id,
            "quilt_web_host": self.quilt_web_host,
            "admin_email": self.admin_email,
            "db_instance_class": self.db_instance_class,
            "search_instance_type": self.search_instance_type,
            "search_volume_size": self.search_volume_size,
        }

        # Add pattern-specific vars
        if self.pattern == "external-iam":
            if not self.iam_template_url:
                # Use default IAM template URL
                vars_dict["iam_template_url"] = self._default_iam_template_url()
            else:
                vars_dict["iam_template_url"] = self.iam_template_url

            vars_dict["template_url"] = (
                self.app_template_url or self._default_app_template_url()
            )
        else:
            vars_dict["template_url"] = self._default_monolithic_template_url()

        return vars_dict

    def _default_iam_template_url(self) -> str:
        """Default IAM template URL.

        Returns:
            S3 URL for IAM template
        """
        return (
            f"https://quilt-templates-{self.environment}-{self.aws_account_id}"
            f".s3.{self.aws_region}.amazonaws.com/quilt-iam.yaml"
        )

    def _default_app_template_url(self) -> str:
        """Default application template URL.

        Returns:
            S3 URL for application template
        """
        return (
            f"https://quilt-templates-{self.environment}-{self.aws_account_id}"
            f".s3.{self.aws_region}.amazonaws.com/quilt-app.yaml"
        )

    def _default_monolithic_template_url(self) -> str:
        """Default monolithic template URL.

        Returns:
            S3 URL for monolithic template
        """
        return (
            f"https://quilt-templates-{self.environment}-{self.aws_account_id}"
            f".s3.{self.aws_region}.amazonaws.com/quilt-monolithic.yaml"
        )

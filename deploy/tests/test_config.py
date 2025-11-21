"""Tests for configuration management."""

from pathlib import Path

import pytest

from lib.config import DeploymentConfig


def test_vpc_selection():
    """Test VPC selection logic."""
    vpcs = [
        {"vpc_id": "vpc-default", "name": "default", "is_default": True},
        {"vpc_id": "vpc-staging", "name": "quilt-staging", "is_default": False},
        {"vpc_id": "vpc-other", "name": "other", "is_default": False},
    ]

    vpc = DeploymentConfig._select_vpc(vpcs)
    assert vpc["vpc_id"] == "vpc-staging"


def test_vpc_selection_fallback():
    """Test VPC selection fallback to non-default."""
    vpcs = [
        {"vpc_id": "vpc-default", "name": "default", "is_default": True},
        {"vpc_id": "vpc-other", "name": "other", "is_default": False},
    ]

    vpc = DeploymentConfig._select_vpc(vpcs)
    assert vpc["vpc_id"] == "vpc-other"


def test_vpc_selection_no_suitable():
    """Test VPC selection with no suitable VPC."""
    vpcs = [
        {"vpc_id": "vpc-default", "name": "default", "is_default": True},
    ]

    with pytest.raises(ValueError, match="No suitable VPC found"):
        DeploymentConfig._select_vpc([vpcs[0]])


def test_subnet_selection():
    """Test subnet selection logic."""
    subnets = [
        {
            "subnet_id": "subnet-1",
            "vpc_id": "vpc-123",
            "classification": "public",
        },
        {
            "subnet_id": "subnet-2",
            "vpc_id": "vpc-123",
            "classification": "public",
        },
        {
            "subnet_id": "subnet-3",
            "vpc_id": "vpc-123",
            "classification": "private",
        },
    ]

    selected = DeploymentConfig._select_subnets(subnets, "vpc-123")
    assert len(selected) == 2
    assert all(s["classification"] == "public" for s in selected)


def test_subnet_selection_insufficient():
    """Test subnet selection with insufficient subnets."""
    subnets = [
        {
            "subnet_id": "subnet-1",
            "vpc_id": "vpc-123",
            "classification": "public",
        },
    ]

    with pytest.raises(ValueError, match="Need at least 2 public subnets"):
        DeploymentConfig._select_subnets(subnets, "vpc-123")


def test_certificate_selection():
    """Test certificate selection logic."""
    certificates = [
        {
            "arn": "arn:aws:acm:us-east-1:123:certificate/abc",
            "domain_name": "*.example.com",
            "status": "ISSUED",
        },
        {
            "arn": "arn:aws:acm:us-east-1:123:certificate/def",
            "domain_name": "*.other.com",
            "status": "ISSUED",
        },
    ]

    cert = DeploymentConfig._select_certificate(certificates, "example.com")
    assert cert["domain_name"] == "*.example.com"


def test_certificate_selection_no_match():
    """Test certificate selection with no match."""
    certificates = [
        {
            "arn": "arn:aws:acm:us-east-1:123:certificate/abc",
            "domain_name": "*.other.com",
            "status": "ISSUED",
        },
    ]

    with pytest.raises(ValueError, match="No valid certificate found"):
        DeploymentConfig._select_certificate(certificates, "example.com")


def test_route53_zone_selection():
    """Test Route53 zone selection logic."""
    zones = [
        {"zone_id": "Z123", "domain_name": "example.com.", "private": False},
        {"zone_id": "Z456", "domain_name": "other.com.", "private": False},
    ]

    zone = DeploymentConfig._select_route53_zone(zones, "example.com")
    assert zone["zone_id"] == "Z123"


def test_route53_zone_selection_no_match():
    """Test Route53 zone selection with no match."""
    zones = [
        {"zone_id": "Z123", "domain_name": "other.com.", "private": False},
    ]

    with pytest.raises(ValueError, match="No Route53 zone found"):
        DeploymentConfig._select_route53_zone(zones, "example.com")


def test_terraform_vars_external_iam():
    """Test Terraform variables for external IAM pattern."""
    config = DeploymentConfig(
        deployment_name="test-deployment",
        aws_region="us-east-1",
        aws_account_id="123456789012",
        environment="test",
        vpc_id="vpc-123",
        subnet_ids=["subnet-1", "subnet-2"],
        security_group_ids=["sg-1"],
        certificate_arn="arn:aws:acm:us-east-1:123:certificate/abc",
        route53_zone_id="Z123",
        domain_name="example.com",
        quilt_web_host="test.example.com",
        admin_email="admin@example.com",
        pattern="external-iam",
    )

    vars_dict = config.to_terraform_vars()

    assert vars_dict["name"] == "test-deployment"
    assert vars_dict["aws_region"] == "us-east-1"
    assert vars_dict["vpc_id"] == "vpc-123"
    assert "iam_template_url" in vars_dict
    assert "template_url" in vars_dict


def test_terraform_vars_inline_iam():
    """Test Terraform variables for inline IAM pattern."""
    config = DeploymentConfig(
        deployment_name="test-deployment",
        aws_region="us-east-1",
        aws_account_id="123456789012",
        environment="test",
        vpc_id="vpc-123",
        subnet_ids=["subnet-1", "subnet-2"],
        security_group_ids=["sg-1"],
        certificate_arn="arn:aws:acm:us-east-1:123:certificate/abc",
        route53_zone_id="Z123",
        domain_name="example.com",
        quilt_web_host="test.example.com",
        admin_email="admin@example.com",
        pattern="inline-iam",
    )

    vars_dict = config.to_terraform_vars()

    assert vars_dict["name"] == "test-deployment"
    assert "iam_template_url" not in vars_dict
    assert "template_url" in vars_dict


# New tests for spec 09-tf-deploy-infrastructure-spec.md


def test_get_required_cfn_parameters():
    """Test required CloudFormation parameters.

    Spec: 09-tf-deploy-infrastructure-spec.md lines 640-657

    Tests that get_required_cfn_parameters() returns the minimal
    required parameters for CloudFormation deployment.
    """
    config = DeploymentConfig(
        deployment_name="test-deployment",
        aws_region="us-east-1",
        aws_account_id="123456789012",
        environment="test",
        vpc_id="vpc-123",
        subnet_ids=["subnet-1", "subnet-2"],
        security_group_ids=["sg-1"],
        certificate_arn="arn:aws:acm:us-east-1:123:certificate/abc",
        route53_zone_id="Z123",
        domain_name="example.com",
        quilt_web_host="test.example.com",
        admin_email="test@example.com",
        pattern="external-iam",
    )

    params = config.get_required_cfn_parameters()

    assert params == {
        "AdminEmail": "test@example.com",
        "CertificateArnELB": "arn:aws:acm:us-east-1:123:certificate/abc",
        "QuiltWebHost": "test.example.com",
        "PasswordAuth": "Enabled",
    }


def test_optional_parameters_omitted_when_not_configured():
    """Test optional parameters are omitted when not configured.

    Spec: 09-tf-deploy-infrastructure-spec.md lines 660-670

    Tests that get_optional_cfn_parameters() returns an empty dict
    when no authentication parameters are configured.
    """
    config = DeploymentConfig(
        deployment_name="test-deployment",
        aws_region="us-east-1",
        aws_account_id="123456789012",
        environment="test",
        vpc_id="vpc-123",
        subnet_ids=["subnet-1", "subnet-2"],
        security_group_ids=["sg-1"],
        certificate_arn="arn:aws:acm:us-east-1:123:certificate/abc",
        route53_zone_id="Z123",
        domain_name="example.com",
        quilt_web_host="test.example.com",
        admin_email="test@example.com",
        pattern="external-iam",
        google_client_secret=None,
        okta_client_secret=None,
    )

    params = config.get_optional_cfn_parameters()

    assert params == {}  # No optional params when nothing configured


def test_optional_parameters_included_when_configured():
    """Test optional parameters are included when configured.

    Spec: 09-tf-deploy-infrastructure-spec.md lines 673-687

    Tests that get_optional_cfn_parameters() returns Google OAuth
    parameters when google_client_secret is configured.
    """
    config = DeploymentConfig(
        deployment_name="test-deployment",
        aws_region="us-east-1",
        aws_account_id="123456789012",
        environment="test",
        vpc_id="vpc-123",
        subnet_ids=["subnet-1", "subnet-2"],
        security_group_ids=["sg-1"],
        certificate_arn="arn:aws:acm:us-east-1:123:certificate/abc",
        route53_zone_id="Z123",
        domain_name="example.com",
        quilt_web_host="test.example.com",
        admin_email="test@example.com",
        pattern="external-iam",
        google_client_secret="secret123",
        google_client_id="client-id",
    )

    params = config.get_optional_cfn_parameters()

    assert params == {
        "GoogleAuth": "Enabled",
        "GoogleClientId": "client-id",
        "GoogleClientSecret": "secret123",
    }


def test_optional_parameters_okta_configured():
    """Test Okta OAuth parameters when configured.

    Tests that get_optional_cfn_parameters() returns Okta OAuth
    parameters when okta_client_secret is configured.
    """
    config = DeploymentConfig(
        deployment_name="test-deployment",
        aws_region="us-east-1",
        aws_account_id="123456789012",
        environment="test",
        vpc_id="vpc-123",
        subnet_ids=["subnet-1", "subnet-2"],
        security_group_ids=["sg-1"],
        certificate_arn="arn:aws:acm:us-east-1:123:certificate/abc",
        route53_zone_id="Z123",
        domain_name="example.com",
        quilt_web_host="test.example.com",
        admin_email="test@example.com",
        pattern="external-iam",
        okta_client_secret="okta-secret",
        okta_client_id="okta-client",
        okta_base_url="https://example.okta.com",
    )

    params = config.get_optional_cfn_parameters()

    assert params == {
        "OktaAuth": "Enabled",
        "OktaBaseUrl": "https://example.okta.com",
        "OktaClientId": "okta-client",
        "OktaClientSecret": "okta-secret",
    }


def test_optional_parameters_multiple_auth_providers():
    """Test multiple auth providers configured simultaneously.

    Tests that get_optional_cfn_parameters() returns both Google and
    Okta parameters when both are configured.
    """
    config = DeploymentConfig(
        deployment_name="test-deployment",
        aws_region="us-east-1",
        aws_account_id="123456789012",
        environment="test",
        vpc_id="vpc-123",
        subnet_ids=["subnet-1", "subnet-2"],
        security_group_ids=["sg-1"],
        certificate_arn="arn:aws:acm:us-east-1:123:certificate/abc",
        route53_zone_id="Z123",
        domain_name="example.com",
        quilt_web_host="test.example.com",
        admin_email="test@example.com",
        pattern="external-iam",
        google_client_secret="google-secret",
        google_client_id="google-client",
        okta_client_secret="okta-secret",
        okta_client_id="okta-client",
        okta_base_url="https://example.okta.com",
    )

    params = config.get_optional_cfn_parameters()

    assert params == {
        "GoogleAuth": "Enabled",
        "GoogleClientId": "google-client",
        "GoogleClientSecret": "google-secret",
        "OktaAuth": "Enabled",
        "OktaBaseUrl": "https://example.okta.com",
        "OktaClientId": "okta-client",
        "OktaClientSecret": "okta-secret",
    }


def test_get_terraform_infrastructure_config():
    """Test Terraform infrastructure configuration generation.

    Spec: 09-tf-deploy-infrastructure-spec.md lines 255-300

    Tests that get_terraform_infrastructure_config() returns a complete
    configuration dict with all required infrastructure parameters.
    """
    config = DeploymentConfig(
        deployment_name="test-deployment",
        aws_region="us-east-1",
        aws_account_id="123456789012",
        environment="test",
        vpc_id="vpc-123",
        subnet_ids=["subnet-1", "subnet-2", "subnet-3", "subnet-4"],
        security_group_ids=["sg-1"],
        certificate_arn="arn:aws:acm:us-east-1:123:certificate/abc",
        route53_zone_id="Z123",
        domain_name="example.com",
        quilt_web_host="test.example.com",
        admin_email="admin@example.com",
        pattern="external-iam",
        db_instance_class="db.t3.micro",
        search_instance_type="t3.small.elasticsearch",
        search_volume_size=10,
    )

    infra_config = config.get_terraform_infrastructure_config()

    # Verify core identity fields
    assert infra_config["name"] == "test-deployment"

    # Verify template file path
    assert "template_file" in infra_config
    template_file = infra_config["template_file"]
    assert template_file.endswith("quilt-app.yaml")

    # Verify network configuration
    assert infra_config["create_new_vpc"] is False
    assert infra_config["vpc_id"] == "vpc-123"
    assert infra_config["intra_subnets"] == ["subnet-1", "subnet-2"]
    assert infra_config["private_subnets"] == ["subnet-1", "subnet-2"]
    assert infra_config["public_subnets"] == ["subnet-1", "subnet-2", "subnet-3", "subnet-4"]
    assert infra_config["user_security_group"] == "sg-1"

    # Verify database configuration
    assert infra_config["db_instance_class"] == "db.t3.micro"
    assert infra_config["db_multi_az"] is False
    assert infra_config["db_deletion_protection"] is False

    # Verify ElasticSearch configuration
    assert infra_config["search_instance_type"] == "t3.small.elasticsearch"
    assert infra_config["search_instance_count"] == 1
    assert infra_config["search_volume_size"] == 10
    assert infra_config["search_dedicated_master_enabled"] is False
    assert infra_config["search_zone_awareness_enabled"] is False

    # Verify CloudFormation parameters
    assert "parameters" in infra_config
    params = infra_config["parameters"]
    assert params["AdminEmail"] == "admin@example.com"
    assert params["CertificateArnELB"] == "arn:aws:acm:us-east-1:123:certificate/abc"
    assert params["QuiltWebHost"] == "test.example.com"
    assert params["PasswordAuth"] == "Enabled"


def test_get_terraform_infrastructure_config_with_auth():
    """Test infrastructure config includes optional auth parameters.

    Tests that get_terraform_infrastructure_config() merges required
    and optional parameters correctly.
    """
    config = DeploymentConfig(
        deployment_name="test-deployment",
        aws_region="us-east-1",
        aws_account_id="123456789012",
        environment="test",
        vpc_id="vpc-123",
        subnet_ids=["subnet-1", "subnet-2"],
        security_group_ids=["sg-1"],
        certificate_arn="arn:aws:acm:us-east-1:123:certificate/abc",
        route53_zone_id="Z123",
        domain_name="example.com",
        quilt_web_host="test.example.com",
        admin_email="admin@example.com",
        pattern="external-iam",
        google_client_secret="secret123",
        google_client_id="client-id",
    )

    infra_config = config.get_terraform_infrastructure_config()

    # Verify merged parameters include both required and optional
    params = infra_config["parameters"]
    assert params["AdminEmail"] == "admin@example.com"
    assert params["GoogleAuth"] == "Enabled"
    assert params["GoogleClientId"] == "client-id"
    assert params["GoogleClientSecret"] == "secret123"


def test_get_terraform_infrastructure_config_external_iam():
    """Test external-iam pattern includes IAM template URL.

    Spec: 09-tf-deploy-infrastructure-spec.md lines 296-298

    Tests that external-iam pattern includes iam_template_url
    and template_url in the configuration.
    """
    config = DeploymentConfig(
        deployment_name="test-deployment",
        aws_region="us-east-1",
        aws_account_id="123456789012",
        environment="test",
        vpc_id="vpc-123",
        subnet_ids=["subnet-1", "subnet-2"],
        security_group_ids=["sg-1"],
        certificate_arn="arn:aws:acm:us-east-1:123:certificate/abc",
        route53_zone_id="Z123",
        domain_name="example.com",
        quilt_web_host="test.example.com",
        admin_email="admin@example.com",
        pattern="external-iam",
        iam_template_url="https://example.com/iam.yaml",
        app_template_url="https://example.com/app.yaml",
    )

    infra_config = config.get_terraform_infrastructure_config()

    assert infra_config["iam_template_url"] == "https://example.com/iam.yaml"
    assert infra_config["template_url"] == "https://example.com/app.yaml"


def test_get_terraform_infrastructure_config_inline_iam():
    """Test inline-iam pattern does not include IAM template URL.

    Tests that inline-iam pattern does not include iam_template_url.
    """
    config = DeploymentConfig(
        deployment_name="test-deployment",
        aws_region="us-east-1",
        aws_account_id="123456789012",
        environment="test",
        vpc_id="vpc-123",
        subnet_ids=["subnet-1", "subnet-2"],
        security_group_ids=["sg-1"],
        certificate_arn="arn:aws:acm:us-east-1:123:certificate/abc",
        route53_zone_id="Z123",
        domain_name="example.com",
        quilt_web_host="test.example.com",
        admin_email="admin@example.com",
        pattern="inline-iam",
    )

    infra_config = config.get_terraform_infrastructure_config()

    assert "iam_template_url" not in infra_config
    assert "template_file" in infra_config


def test_get_intra_subnets():
    """Test intra subnet selection.

    Spec: 09-tf-deploy-infrastructure-spec.md lines 302-310

    Tests that _get_intra_subnets() returns the first 2 subnets
    for isolated resources (DB, ElasticSearch).
    """
    config = DeploymentConfig(
        deployment_name="test-deployment",
        aws_region="us-east-1",
        aws_account_id="123456789012",
        environment="test",
        vpc_id="vpc-123",
        subnet_ids=["subnet-1", "subnet-2", "subnet-3", "subnet-4"],
        security_group_ids=["sg-1"],
        certificate_arn="arn:aws:acm:us-east-1:123:certificate/abc",
        route53_zone_id="Z123",
        domain_name="example.com",
        quilt_web_host="test.example.com",
        admin_email="admin@example.com",
        pattern="external-iam",
    )

    intra_subnets = config._get_intra_subnets()

    assert intra_subnets == ["subnet-1", "subnet-2"]
    assert len(intra_subnets) == 2


def test_get_private_subnets():
    """Test private subnet selection.

    Spec: 09-tf-deploy-infrastructure-spec.md lines 312-318

    Tests that _get_private_subnets() returns the first 2 subnets
    for application resources (with NAT gateway access).
    """
    config = DeploymentConfig(
        deployment_name="test-deployment",
        aws_region="us-east-1",
        aws_account_id="123456789012",
        environment="test",
        vpc_id="vpc-123",
        subnet_ids=["subnet-1", "subnet-2", "subnet-3", "subnet-4"],
        security_group_ids=["sg-1"],
        certificate_arn="arn:aws:acm:us-east-1:123:certificate/abc",
        route53_zone_id="Z123",
        domain_name="example.com",
        quilt_web_host="test.example.com",
        admin_email="admin@example.com",
        pattern="external-iam",
    )

    private_subnets = config._get_private_subnets()

    assert private_subnets == ["subnet-1", "subnet-2"]
    assert len(private_subnets) == 2


def test_get_template_file_path_external_iam():
    """Test template file path for external-iam pattern.

    Spec: 09-tf-deploy-infrastructure-spec.md lines 320-330

    Tests that get_template_file_path() returns the path to
    quilt-app.yaml for external-iam pattern.
    """
    config = DeploymentConfig(
        deployment_name="test-deployment",
        aws_region="us-east-1",
        aws_account_id="123456789012",
        environment="test",
        vpc_id="vpc-123",
        subnet_ids=["subnet-1", "subnet-2"],
        security_group_ids=["sg-1"],
        certificate_arn="arn:aws:acm:us-east-1:123:certificate/abc",
        route53_zone_id="Z123",
        domain_name="example.com",
        quilt_web_host="test.example.com",
        admin_email="admin@example.com",
        pattern="external-iam",
    )

    template_path = config.get_template_file_path()

    assert template_path.endswith("templates/quilt-app.yaml")
    assert Path(template_path).name == "quilt-app.yaml"


def test_get_template_file_path_inline_iam():
    """Test template file path for inline-iam pattern.

    Spec: 09-tf-deploy-infrastructure-spec.md lines 320-330

    Tests that get_template_file_path() returns the path to
    quilt-cfn.yaml for inline-iam pattern.
    """
    config = DeploymentConfig(
        deployment_name="test-deployment",
        aws_region="us-east-1",
        aws_account_id="123456789012",
        environment="test",
        vpc_id="vpc-123",
        subnet_ids=["subnet-1", "subnet-2"],
        security_group_ids=["sg-1"],
        certificate_arn="arn:aws:acm:us-east-1:123:certificate/abc",
        route53_zone_id="Z123",
        domain_name="example.com",
        quilt_web_host="test.example.com",
        admin_email="admin@example.com",
        pattern="inline-iam",
    )

    template_path = config.get_template_file_path()

    assert template_path.endswith("templates/quilt-monolithic.yaml")
    assert Path(template_path).name == "quilt-monolithic.yaml"


def test_get_intra_subnets_with_two_subnets():
    """Test intra subnets with exactly 2 subnets available."""
    config = DeploymentConfig(
        deployment_name="test-deployment",
        aws_region="us-east-1",
        aws_account_id="123456789012",
        environment="test",
        vpc_id="vpc-123",
        subnet_ids=["subnet-1", "subnet-2"],
        security_group_ids=["sg-1"],
        certificate_arn="arn:aws:acm:us-east-1:123:certificate/abc",
        route53_zone_id="Z123",
        domain_name="example.com",
        quilt_web_host="test.example.com",
        admin_email="admin@example.com",
        pattern="external-iam",
    )

    intra_subnets = config._get_intra_subnets()

    assert intra_subnets == ["subnet-1", "subnet-2"]
    assert len(intra_subnets) == 2


def test_get_private_subnets_with_two_subnets():
    """Test private subnets with exactly 2 subnets available."""
    config = DeploymentConfig(
        deployment_name="test-deployment",
        aws_region="us-east-1",
        aws_account_id="123456789012",
        environment="test",
        vpc_id="vpc-123",
        subnet_ids=["subnet-1", "subnet-2"],
        security_group_ids=["sg-1"],
        certificate_arn="arn:aws:acm:us-east-1:123:certificate/abc",
        route53_zone_id="Z123",
        domain_name="example.com",
        quilt_web_host="test.example.com",
        admin_email="admin@example.com",
        pattern="external-iam",
    )

    private_subnets = config._get_private_subnets()

    assert private_subnets == ["subnet-1", "subnet-2"]
    assert len(private_subnets) == 2
